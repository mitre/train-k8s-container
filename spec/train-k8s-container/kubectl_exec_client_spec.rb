# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/kubectl_exec_client'

RSpec.describe TrainPlugins::K8sContainer::KubectlExecClient do
  let(:shell) { double(Mixlib::ShellOut) }
  let(:pod) { 'shell-demo' }
  let(:container_name) { 'nginx' }
  let(:namespace) { TrainPlugins::K8sContainer::KubectlExecClient::DEFAULT_NAMESPACE }
  let(:shell_op) { Struct.new(:stdout, :stderr, :exitstatus) }

  subject { described_class.new(pod:, namespace:, container_name:) }
  describe '.instance' do
    it 'should return a kubectl exec object' do
      expect(subject.pod).to eq(pod)
      expect(subject.namespace).to eq(namespace)
      expect(subject.container_name).to eq(container_name)
    end
  end

  describe '#execute' do
    let(:result) { shell_op.new(stdout, stderr, exitstatus) }
    before do
      allow(Mixlib::ShellOut).to receive(:new).and_return(shell)
      allow(shell).to receive(:run_command).and_return(result)
    end

    subject { described_class.new(pod:, namespace:, container_name:).execute(command) }
    context 'on successful command' do
      let(:stdout) { 'root' }
      let(:stderr) { '' }
      let(:exitstatus) { 0 }
      let(:command) { 'whoami' }
      it '#stdout returns the output of the given command' do
        expect(subject.stdout).to eq('root')
      end

      it '#stderr returns empty' do
        expect(subject.stderr).to be_empty
      end

      it '#exit_status returns zero exit code' do
        expect(subject.exit_status).to eq(0)
      end
    end

    context 'on wrong command' do
      let(:stdout) { '' }
      let(:stderr) do
        "chmod: missing operand\nTry 'chmod --help' for more information.\ncommand terminated with exit code 1\n"
      end
      let(:exitstatus) { 1 }
      let(:command) { 'chmod' }
      it '#stdout returns empty' do
        expect(subject.stdout).to be_empty
      end

      it '#stderr returns error message' do
        expect(subject.stderr).not_to be_empty
      end

      it '#exit_status returns non-zero exit code' do
        expect(subject.exit_status).not_to eq(0)
      end
    end
  end

  describe '#execute_raw' do
    it 'properly escapes commands with shell operators' do
      client = described_class.new(pod: 'test', namespace: 'default', container_name: 'test')
      instruction = client.send(:build_raw_instruction, 'test -x /bin/bash && echo OK')

      # Shellwords.escape will escape spaces and special chars
      expect(instruction).to include('test\\ -x\\ /bin/bash\\ \\&\\&\\ echo\\ OK')
      expect(instruction).to include('-- /bin/sh -c')
    end

    it 'handles commands with pipes' do
      client = described_class.new(pod: 'test', namespace: 'default', container_name: 'test')
      instruction = client.send(:build_raw_instruction, 'cat file | grep test')

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

      it 'uses shellout by default (PTY disabled)' do
        client.execute('test')
        expect(client).to have_received(:execute_via_shellout)
        expect(client).not_to have_received(:execute_via_pty)
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

        client_pty = described_class.new(pod: 'test', namespace: 'default', container_name: 'test', use_pty: true)

        # Mock SessionManager to raise PTY error
        mock_session = instance_double(TrainPlugins::K8sContainer::PtySession)
        allow(TrainPlugins::K8sContainer::SessionManager.instance).to receive(:get_session)
          .and_raise(TrainPlugins::K8sContainer::PtySession::PtyError.new('PTY failed'))

        # Mock successful shellout fallback
        allow(client_pty).to receive(:execute_via_shellout).and_call_original
        allow(Mixlib::ShellOut).to receive(:new).and_return(shell)
        allow(shell).to receive(:run_command).and_return(shell_op.new('output', '', 0))

        # First call should catch PTY error and fallback
        result = client_pty.execute('test')
        expect(result.stdout).to eq('output')

        # Verify PTY fallback is now disabled
        expect(client_pty.instance_variable_get(:@pty_fallback_disabled)).to be true
      end
    end
  end
end
