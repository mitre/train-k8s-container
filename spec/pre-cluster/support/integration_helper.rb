# frozen_string_literal: true

# Integration test helpers for real kubectl/pod testing
module IntegrationHelper
  # Check if kubectl is available
  def kubectl_available?
    system('kubectl version --client > /dev/null 2>&1')
  end

  # Check if a specific pod is running
  def pod_running?(pod, namespace: 'default')
    system("kubectl get pod #{pod} -n #{namespace} > /dev/null 2>&1")
  end

  # Check if test pods exist (used by CI)
  def test_pods_available?
    pod_running?('test-ubuntu') && pod_running?('test-alpine')
  end

  # Skip integration tests if requirements not met
  def skip_if_no_integration_env
    skip 'kubectl not available' unless kubectl_available?
    skip 'test pods not running (run: kubectl run test-ubuntu --image=ubuntu:22.04 -- sleep 3600)' unless test_pods_available?
  end
end

RSpec.configure do |config|
  config.include IntegrationHelper, type: :integration
end
