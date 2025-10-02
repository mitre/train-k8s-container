# frozen_string_literal: true

require_relative '../spec_helper'
require 'train'
require 'train-k8s-container/platform'
require 'train-k8s-container/version'

# Test connection class that includes Platform module
class TestPlatformConnection < Train::Plugins::Transport::BaseConnection
  include TrainPlugins::K8sContainer::Platform

  def initialize
    # BaseConnection needs options, but we don't need real ones for platform test
    super({})
  end
end

RSpec.describe TrainPlugins::K8sContainer::Platform do
  subject { TestPlatformConnection.new }

  describe '#platform' do
    it 'returns k8s-container platform name' do
      expect(subject.platform.name).to eq('k8s-container')
    end

    it 'includes cloud family' do
      expect(subject.platform.families.keys.map(&:name)).to include('cloud')
    end

    it 'includes unix family' do
      expect(subject.platform.families.keys.map(&:name)).to include('unix')
    end

    it 'uses plugin version as release' do
      expect(subject.platform.release).to eq(TrainPlugins::K8sContainer::VERSION)
    end
  end
end
