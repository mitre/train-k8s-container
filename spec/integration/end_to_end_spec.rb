# frozen_string_literal: true

require_relative '../spec_helper'
require 'train'
require 'train-k8s-container'

RSpec.describe 'End-to-End Integration', type: :integration do
  before(:all) do
    skip_if_no_integration_env
  end

  before(:each) do
    # Reset platform registry to prevent accumulation across tests
    Train::Platforms.__reset if defined?(Train::Platforms.__reset)
  end

  after(:each) do
    TrainPlugins::K8sContainer::SessionManager.instance.cleanup_all
  end
