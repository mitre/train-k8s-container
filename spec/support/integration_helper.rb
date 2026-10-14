# frozen_string_literal: true

# Integration test helpers for real kubectl/pod testing
module IntegrationHelper
  def require_integration_env!
    raise 'kubectl not available' unless system('kubectl', 'version', '--client', out: File::NULL, err: File::NULL)

    ready = system('kubectl', 'wait', '-n', 'default', '--for=condition=Ready',
                   'pod/test-ubuntu', 'pod/test-alpine', '--timeout=5s', out: File::NULL, err: File::NULL)
    raise 'Test pods are not ready; run test/setup-kind.sh first' unless ready
  end
end

RSpec.configure do |config|
  config.include IntegrationHelper, type: :integration
end
