# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container'

RSpec.describe 'PtySession Integration', type: :integration do
  before(:all) do
    skip_if_no_integration_env
  end

  let(:kubectl_client) do
    TrainPlugins::K8sContainer::KubectlExecClient.new(
      pod: 'test-ubuntu',
      container_name: 'test-ubuntu',
      namespace: 'default',
      use_pty: true
    )
  end

  let(:session_key) { 'default/test-ubuntu/test-ubuntu' }
  let(:kubectl_cmd) { 'kubectl exec --stdin test-ubuntu -n default -c test-ubuntu' }

  describe 'PTY session lifecycle' do
    after(:each) do
      # Cleanup sessions after each test
      TrainPlugins::K8sContainer::SessionManager.instance.cleanup_all
    end

    it 'creates and connects PTY session' do
      session = TrainPlugins::K8sContainer::SessionManager.instance.get_session(
        session_key,
        kubectl_cmd: kubectl_cmd,
        shell: '/bin/bash'
      )

      expect(session).to be_a(TrainPlugins::K8sContainer::PtySession)
      expect(session.connected?).to be true
      expect(session.healthy?).to be true
    end

    it 'executes commands via PTY' do
      session = TrainPlugins::K8sContainer::SessionManager.instance.get_session(
        session_key,
        kubectl_cmd: kubectl_cmd,
        shell: '/bin/bash'
      )

      result = session.execute('whoami')

      expect(result).to be_a(Train::Extras::CommandResult)
      expect(result.exit_status).to eq(0)
      expect(result.stdout).to eq('root')
    end

    it 'reuses session for multiple commands' do
      session = TrainPlugins::K8sContainer::SessionManager.instance.get_session(
        session_key,
        kubectl_cmd: kubectl_cmd
      )

      result1 = session.execute('echo test1')
      result2 = session.execute('echo test2')
      result3 = session.execute('echo test3')

      expect(result1.stdout).to eq('test1')
      expect(result2.stdout).to eq('test2')
      expect(result3.stdout).to eq('test3')
    end

    it 'handles failed commands correctly' do
      session = TrainPlugins::K8sContainer::SessionManager.instance.get_session(
        session_key,
        kubectl_cmd: kubectl_cmd
      )

      result = session.execute('nonexistent-command')

      expect(result.exit_status).not_to eq(0)
      expect(result.stderr).to include('not found')
    end

    it 'handles multi-line output' do
      session = TrainPlugins::K8sContainer::SessionManager.instance.get_session(
        session_key,
        kubectl_cmd: kubectl_cmd
      )

      result = session.execute('ls -1 /etc | head -5')

      expect(result.exit_status).to eq(0)
      expect(result.stdout.lines.count).to be >= 5
    end

    it 'properly parses exit codes using subshells' do
      session = TrainPlugins::K8sContainer::SessionManager.instance.get_session(
        session_key,
        kubectl_cmd: kubectl_cmd
      )

      # Test various exit codes using subshells (don't exit main shell)
      result_zero = session.execute('(exit 0); echo $?')
      result_one = session.execute('(exit 1); echo $?')
      result_fortytwo = session.execute('(exit 42); echo $?')

      expect(result_zero.stdout.strip).to eq('0')
      expect(result_one.stdout.strip).to eq('1')
      expect(result_fortytwo.stdout.strip).to eq('42')
    end

    it 'cleans up session properly' do
      session = TrainPlugins::K8sContainer::SessionManager.instance.get_session(
        session_key,
        kubectl_cmd: kubectl_cmd
      )

      pid = session.pid
      expect(pid).not_to be_nil

      session.cleanup

      expect(session.connected?).to be_falsey
      # NOTE: Process may not be immediately dead due to async cleanup
      # This is acceptable and tested in unit tests with mocks
    end
  end

  describe 'PTY session via KubectlExecClient' do
    it 'uses PTY session when enabled' do
      # First command creates session
      result1 = kubectl_client.execute('echo test1')
      expect(result1.stdout).to eq('test1')

      # Verify session was created
      expect(TrainPlugins::K8sContainer::SessionManager.instance.session_count).to eq(1)

      # Second command reuses session
      result2 = kubectl_client.execute('echo test2')
      expect(result2.stdout).to eq('test2')

      # Still only one session
      expect(TrainPlugins::K8sContainer::SessionManager.instance.session_count).to eq(1)
    end
  end
end
