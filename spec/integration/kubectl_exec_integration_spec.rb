# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container'

RSpec.describe 'KubectlExecClient Integration', type: :integration do
  before(:all) do
    skip_if_no_integration_env
  end

  after(:each) do
    TrainPlugins::K8sContainer::SessionManager.instance.cleanup_all
  end

  let(:ubuntu_client) do
    TrainPlugins::K8sContainer::KubectlExecClient.new(
      pod: 'test-ubuntu',
      container_name: 'test-ubuntu',
      namespace: 'default',
      use_pty: false # Test shellout path
    )
  end

  let(:ubuntu_client_pty) do
    TrainPlugins::K8sContainer::KubectlExecClient.new(
      pod: 'test-ubuntu',
      container_name: 'test-ubuntu',
      namespace: 'default',
      use_pty: true # Test PTY path
    )
  end

  let(:alpine_client) do
    TrainPlugins::K8sContainer::KubectlExecClient.new(
      pod: 'test-alpine',
      container_name: 'test-alpine',
      namespace: 'default',
      use_pty: false
    )
  end