# frozen_string_literal: true

require_relative '../spec_helper'
require 'train'
require 'train-k8s-container/platform'
require 'train-k8s-container/version'
require 'train-k8s-container/shell_detector'

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

    it 'includes container family' do
      expect(subject.platform.families.keys.map(&:name)).to include('container')
    end

    it 'uses plugin version as release' do
      expect(subject.platform.release).to eq(TrainPlugins::K8sContainer::VERSION)
    end
  end

  describe 'dynamic platform families' do
    it 'declares base families (cloud, container) always' do
      families = subject.platform.families.keys.map(&:name)
      expect(families).to include('cloud')
      expect(families).to include('container')
    end

    it 'does not declare OS family when container OS is unknown' do
      # Without shell detection, container_os is unknown
      # Platform should not declare unix or windows family
      families = subject.platform.families.keys.map(&:name)
      expect(families).to include('cloud', 'container')
      expect(families).not_to include('unix')
      expect(families).not_to include('windows')
    end

    it 'declares unix family when container OS is unix' do
      # Reset Train's platform registry to avoid accumulation from previous tests
      Train::Platforms.__reset
      connection = TestPlatformConnection.new

      # Mock shell detector with Unix container
      mock_detector = instance_double(TrainPlugins::K8sContainer::ShellDetector)
      allow(mock_detector).to receive(:container_os).and_return(:unix)
      allow(mock_detector).to receive(:detect).and_return('/bin/bash')
      allow(connection).to receive(:detect_shell).and_wrap_original do |_method|
        connection.instance_variable_set(:@shell_detector, mock_detector)
        mock_detector.detect
      end

      families = connection.platform.families.keys.map(&:name)
      expect(families).to include('cloud', 'container', 'unix')
      expect(families).not_to include('windows')
    end

    it 'declares windows family when container OS is windows' do
      # Reset Train's platform registry to avoid accumulation from previous tests
      Train::Platforms.__reset
      connection = TestPlatformConnection.new

      # Mock shell detector with Windows container
      mock_detector = instance_double(TrainPlugins::K8sContainer::ShellDetector)
      allow(mock_detector).to receive(:container_os).and_return(:windows)
      allow(mock_detector).to receive(:detect).and_return('cmd.exe')
      allow(connection).to receive(:detect_shell).and_wrap_original do |_method|
        connection.instance_variable_set(:@shell_detector, mock_detector)
        mock_detector.detect
      end

      families = connection.platform.families.keys.map(&:name)
      expect(families).to include('cloud', 'container', 'windows')
      expect(families).not_to include('unix')
    end
  end
end
