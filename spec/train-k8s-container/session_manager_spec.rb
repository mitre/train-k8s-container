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

  # NOTE: Full integration testing with real PTY sessions happens in
  # integration tests. Unit testing SessionManager with mocks is complex
  # due to singleton state and would require significant test infrastructure.
  # The core logic (Mutex, session pooling) is straightforward and will be
  # validated via integration tests with real pods.
end
