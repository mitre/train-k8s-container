# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/kubectl_exec_client'
require 'train-k8s-container/shell_detector'

RSpec.describe TrainPlugins::K8sContainer::KubectlExecClient do
  let(:shell) { double(Mixlib::ShellOut) }
  let(:pod) { 'shell-demo' }
  let(:container_name) { 'nginx' }
  let(:namespace) { TrainPlugins::K8sContainer::KubectlExecClient::DEFAULT_NAMESPACE }
  let(:shell_op) { Struct.new(:stdout, :stderr, :exitstatus) }

  # Helper to create client with null logger
  let(:null_logger) { Logger.new(IO::NULL) }
  let(:client) { described_class.new(pod:, namespace:, container_name:, logger: null_logger) }

  describe '.instance' do
    it 'should return a kubectl exec object' do
      expect(client.pod).to eq(pod)
      expect(client.namespace).to eq(namespace)
      expect(client.container_name).to eq(container_name)
    end
  end

  describe '#execute' do
    before do
      # Mock Mixlib::ShellOut to return different results based on command
      allow(Mixlib::ShellOut).to receive(:new) do |cmd|
        mock_shell = double('Mixlib::ShellOut')
        allow(mock_shell).to receive(:run_command) do
          # Return appropriate result based on what command is being run
          if cmd.include?('echo test')
            # OS detection
            shell_op.new('test', '', 0)
          elsif cmd.include?('test -x /bin/bash')
            # Shell detection for bash
            shell_op.new('OK', '', 0)
          elsif cmd.include?('whoami')
            # Actual test command
            shell_op.new('root', '', 0)
          elsif cmd.include?('chmod')
            # Error test command
            shell_op.new('', "chmod: missing operand\nTry 'chmod --help' for more information.\ncommand terminated with exit code 1\n", 1)
          else
            # Default
            shell_op.new('', '', 0)
          end
        end
        mock_shell
      end
    end

    context 'on successful command' do
      it '#stdout returns the output of the given command' do
        result = client.execute('whoami')
        expect(result.stdout).to eq('root')
      end

      it '#stderr returns empty' do
        result = client.execute('whoami')
        expect(result.stderr).to be_empty
      end

      it '#exit_status returns zero exit code' do
        result = client.execute('whoami')
        expect(result.exit_status).to eq(0)
      end
    end

    context 'on wrong command' do
      it '#stdout returns empty' do
        result = client.execute('chmod')
        expect(result.stdout).to be_empty
      end

      it '#stderr returns error message' do
        result = client.execute('chmod')
        expect(result.stderr).not_to be_empty
      end

      it '#exit_status returns non-zero exit code' do
        result = client.execute('chmod')
        expect(result.exit_status).not_to eq(0)
      end
    end
  end

  describe '#execute_raw' do
    it 'properly escapes commands with shell operators' do
      client = described_class.new(pod: 'test', namespace: 'default', container_name: 'test')
      command_builder = client.instance_variable_get(:@command_builder)
      instruction = command_builder.with_raw_shell('test -x /bin/bash && echo OK')

      # Shellwords.escape will escape spaces and special chars
      expect(instruction).to include('test\\ -x\\ /bin/bash\\ \\&\\&\\ echo\\ OK')
      expect(instruction).to include('-- /bin/sh -c')
    end

    it 'handles commands with pipes' do
      client = described_class.new(pod: 'test', namespace: 'default', container_name: 'test')
      command_builder = client.instance_variable_get(:@command_builder)
      instruction = command_builder.with_raw_shell('cat file | grep test')

      # Should escape the pipe
      expect(instruction).to include('\\|')
      expect(instruction).to include('-- /bin/sh -c')
    end
  end

  describe 'PTY mode selection' do
    describe '#pty_available?' do
      it 'returns true on Unix platforms' do
        skip 'Running on Windows' if RUBY_PLATFORM.match?(/windows|mswin|msys|mingw|cygwin/)

        client = described_class.new(pod: 'test', namespace: 'default', container_name: 'test')
        expect(client.send(:pty_available?)).to be true
      end

      it 'returns false on Windows platforms' do
        skip 'Not on Windows' unless RUBY_PLATFORM.match?(/windows|mswin|msys|mingw|cygwin/)

        client = described_class.new(pod: 'test', namespace: 'default', container_name: 'test')
        expect(client.send(:pty_available?)).to be false
      end
    end

    describe 'execution path selection' do
      let(:client) { described_class.new(pod: 'test', namespace: 'default', container_name: 'test') }

      before do
        allow(client).to receive(:execute_via_shellout).and_return(
          Train::Extras::CommandResult.new('output', '', 0)
        )
        allow(client).to receive(:execute_via_pty).and_return(
          Train::Extras::CommandResult.new('output', '', 0)
        )
      end

      it 'uses PTY by default (persistent sessions enabled)' do
        skip 'Running on Windows' if RUBY_PLATFORM.match?(/windows|mswin|msys|mingw|cygwin/)

        client.execute('test')
        expect(client).to have_received(:execute_via_pty)
        expect(client).not_to have_received(:execute_via_shellout)
      end

      it 'can opt-out with use_pty: false' do
        client_no_pty = described_class.new(pod: 'test', namespace: 'default', container_name: 'test', use_pty: false)
        allow(client_no_pty).to receive(:execute_via_shellout).and_return(
          Train::Extras::CommandResult.new('output', '', 0)
        )
        allow(client_no_pty).to receive(:execute_via_pty)

        client_no_pty.execute('test')
        expect(client_no_pty).to have_received(:execute_via_shellout)
        expect(client_no_pty).not_to have_received(:execute_via_pty)
      end

      it 'uses shellout when PTY unavailable on Windows' do
        skip 'Not on Windows' unless RUBY_PLATFORM.match?(/windows|mswin|msys|mingw|cygwin/)

        client_pty = described_class.new(pod: 'test', namespace: 'default', container_name: 'test', use_pty: true)
        allow(client_pty).to receive(:execute_via_shellout).and_return(
          Train::Extras::CommandResult.new('output', '', 0)
        )

        client_pty.execute('test')
        expect(client_pty).to have_received(:execute_via_shellout)
      end

      it 'uses PTY when enabled and available' do
        skip 'Running on Windows' if RUBY_PLATFORM.match?(/windows|mswin|msys|mingw|cygwin/)

        client_pty = described_class.new(pod: 'test', namespace: 'default', container_name: 'test', use_pty: true)
        allow(client_pty).to receive(:execute_via_pty).and_return(
          Train::Extras::CommandResult.new('output', '', 0)
        )
        allow(client_pty).to receive(:execute_via_shellout)

        client_pty.execute('test')
        expect(client_pty).to have_received(:execute_via_pty)
        expect(client_pty).not_to have_received(:execute_via_shellout)
      end
    end

    describe 'PTY fallback' do
      it 'disables PTY after persistent errors' do
        skip 'Running on Windows' if RUBY_PLATFORM.match?(/windows|mswin|msys|mingw|cygwin/)

        # Mock logger to suppress ERROR output during test
        mock_logger = instance_double(Logger)
        allow(mock_logger).to receive(:debug)
        allow(mock_logger).to receive(:warn)
        allow(mock_logger).to receive(:error)

        client_pty = described_class.new(
          pod: 'test',
          namespace: 'default',
          container_name: 'test',
          use_pty: true,
          logger: mock_logger
        )

        # Mock SessionManager to raise PTY error
        instance_double(TrainPlugins::K8sContainer::PtySession)
        allow(TrainPlugins::K8sContainer::SessionManager.instance).to receive(:get_session)
          .and_raise(TrainPlugins::K8sContainer::PtySession::PtyError.new('PTY failed'))

        # Mock successful shellout fallback
        allow(client_pty).to receive(:execute_via_shellout).and_call_original
        allow(Mixlib::ShellOut).to receive(:new).and_return(shell)
        allow(shell).to receive(:run_command).and_return(shell_op.new('output', '', 0))

        # First call should catch PTY error and fallback
        result = client_pty.execute('test')
        expect(result.stdout).to eq('output')

        # Verify error was logged (but not output to console)
        expect(mock_logger).to have_received(:error).with(/PTY execution failed/)

        # Verify PTY fallback is now disabled
        expect(client_pty.instance_variable_get(:@pty_fallback_disabled)).to be true
      end
    end
  end
end
