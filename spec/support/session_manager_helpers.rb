# frozen_string_literal: true

module SessionManagerHelpers
  def create_mock_session
    mock = instance_double(TrainPlugins::K8sContainer::PtySession)
    allow(mock).to receive(:cleanup)
    mock
  end

  def expect_session_creation(mock_session)
    expect(TrainPlugins::K8sContainer::PtySession).to receive(:new).and_return(mock_session)
    expect(mock_session).to receive(:connect)
  end

  def reset_session_manager
    TrainPlugins::K8sContainer::SessionManager.instance.instance_variable_set(:@sessions, {})
  end
end

RSpec.configure do |config|
  config.include SessionManagerHelpers, type: :session_manager
end
