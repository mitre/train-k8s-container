# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/session_manager'

RSpec.describe TrainPlugins::K8sContainer::SessionManager do
  let(:session_key) { 'default/test-pod/test-container' }
  let(:kubectl_cmd) { 'kubectl exec --stdin --tty test-pod -n default -c test-container' }

  # Clear singleton between tests
  before do
    described_class.instance.instance_variable_set(:@sessions, {})
  end

  after do
    # Cleanup without calling methods on mocks
    described_class.instance.instance_variable_set(:@sessions, {})
  end

  describe '#session_count' do
    it 'returns session count' do
      expect(described_class.instance.session_count).to eq(0)
    end
  end

  describe '#session_keys' do
    it 'returns array of session keys' do
      expect(described_class.instance.session_keys).to eq([])
    end
  end

  describe 'singleton pattern' do
    it 'returns same instance' do
      instance1 = described_class.instance
      instance2 = described_class.instance
      expect(instance1).to eq(instance2)
    end
  end

  describe '#get_session' do
    it 'creates new session if not exists' do
      mock_session = double('PtySession', healthy?: true, connect: true)
      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new).and_return(mock_session)

      session = described_class.instance.get_session(
        session_key,
        kubectl_cmd: kubectl_cmd,
        shell: '/bin/bash'
      )

      expect(session).to eq(mock_session)
      expect(described_class.instance.session_count).to eq(1)
    end

    it 'reuses existing healthy session' do
      mock_session = double('PtySession', healthy?: true, connect: true)
      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new).and_return(mock_session)

      session1 = described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)
      session2 = described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)

      expect(session1).to eq(session2)
      expect(TrainPlugins::K8sContainer::PtySession).to have_received(:new).once
    end

    it 'recreates unhealthy session' do
      mock_session1 = double('PtySession1', healthy?: false, cleanup: true, connect: true)
      mock_session2 = double('PtySession2', healthy?: true, connect: true)

      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new)
        .and_return(mock_session1, mock_session2)

      # First call creates session1
      described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)

      # Second call finds it unhealthy, recreates as session2
      session = described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)

      expect(session).to eq(mock_session2)
      expect(TrainPlugins::K8sContainer::PtySession).to have_received(:new).twice
    end

    it 'handles session creation failure' do
      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new)
        .and_raise(TrainPlugins::K8sContainer::PtySession::PtyError, 'connection failed')

      expect do
        described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)
      end.to raise_error(TrainPlugins::K8sContainer::PtySession::PtyError)
    end

    it 'cleans up failed session before raising' do
      mock_session = double('PtySession', connect: true, cleanup: true)
      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new).and_return(mock_session)
      allow(mock_session).to receive(:connect).and_raise(TrainPlugins::K8sContainer::PtySession::PtyError)

      expect do
        described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)
      end.to raise_error(TrainPlugins::K8sContainer::PtySession::PtyError)

      expect(described_class.instance.session_count).to eq(0)
    end
  end

  describe '#cleanup_session' do
    it 'removes session from pool' do
      mock_session = double('PtySession', healthy?: true, connect: true, cleanup: true)
      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new).and_return(mock_session)

      described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)
      expect(described_class.instance.session_count).to eq(1)

      described_class.instance.cleanup_session(session_key)
      expect(described_class.instance.session_count).to eq(0)
    end

    it 'calls cleanup on the session' do
      mock_session = double('PtySession', healthy?: true, connect: true, cleanup: true)
      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new).and_return(mock_session)

      described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)

      expect(mock_session).to receive(:cleanup)
      described_class.instance.cleanup_session(session_key)
    end

    it 'propagates cleanup errors' do
      mock_session = double('PtySession', healthy?: true, connect: true)
      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new).and_return(mock_session)
      allow(mock_session).to receive(:cleanup).and_raise(StandardError, 'cleanup failed')

      described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)

      expect do
        described_class.instance.cleanup_session(session_key)
      end.to raise_error(StandardError, 'cleanup failed')

      # Session still removed from pool despite error
      expect(described_class.instance.session_count).to eq(0)
    end
  end

  describe '#cleanup_all' do
    it 'cleans up all sessions' do
      mock_session1 = double('PtySession1', healthy?: true, connect: true, cleanup: true)
      mock_session2 = double('PtySession2', healthy?: true, connect: true, cleanup: true)

      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new)
        .and_return(mock_session1, mock_session2)

      described_class.instance.get_session('key1', kubectl_cmd: kubectl_cmd)
      described_class.instance.get_session('key2', kubectl_cmd: kubectl_cmd)

      expect(described_class.instance.session_count).to eq(2)

      expect(mock_session1).to receive(:cleanup)
      expect(mock_session2).to receive(:cleanup)

      described_class.instance.cleanup_all

      expect(described_class.instance.session_count).to eq(0)
    end

    it 'is thread-safe' do
      # This tests that cleanup_all properly synchronizes
      mock_session = double('PtySession', healthy?: true, connect: true, cleanup: true)
      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new).and_return(mock_session)

      described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)

      # Should not raise despite concurrent access
      expect do
        described_class.instance.cleanup_all
      end.not_to raise_error
    end
  end

  describe 'thread safety' do
    it 'handles concurrent get_session calls' do
      call_count = 0
      mock_sessions = 5.times.map do
        double('PtySession', healthy?: true, connect: true)
      end

      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new) do
        call_count += 1
        mock_sessions[call_count - 1]
      end

      threads = 5.times.map do |i|
        Thread.new do
          described_class.instance.get_session("key#{i}", kubectl_cmd: kubectl_cmd)
        end
      end

      threads.each(&:join)

      expect(described_class.instance.session_count).to eq(5)
      expect(call_count).to eq(5)
    end

    it 'prevents race conditions when creating same session' do
      mock_session = double('PtySession', healthy?: true, connect: true)
      creation_count = 0

      allow(TrainPlugins::K8sContainer::PtySession).to receive(:new) do
        creation_count += 1
        sleep(0.01) # Simulate slow creation
        mock_session
      end

      # Multiple threads try to create same session simultaneously
      threads = 3.times.map do
        Thread.new do
          described_class.instance.get_session(session_key, kubectl_cmd: kubectl_cmd)
        end
      end

      threads.each(&:join)

      # Should only create once despite concurrent requests
      expect(creation_count).to eq(1)
      expect(described_class.instance.session_count).to eq(1)
    end
  end
end
