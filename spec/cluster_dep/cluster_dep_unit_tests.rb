# frozen_string_literal: true

require_relative '../spec_helper'
require 'train'
require 'train-k8s-container'

RSpec.describe 'Cluster-dep unit testing', type: :integration do
  before(:each) do
    # Reset platform registry to prevent accumulation across tests
    Train::Platforms.__reset if defined?(Train::Platforms.__reset)
  end

  after(:each) do
    TrainPlugins::K8sContainer::SessionManager.instance.cleanup_all
  end

  describe 'Train.create factory' do
    it 'creates k8s-container connection via Train factory' do
      train = Train.create('k8s-container', {
                             pod: 'test-ubuntu',
                             container_name: 'test-ubuntu',
                             namespace: 'default',
                           })

      expect(train).to be_a(TrainPlugins::K8sContainer::Transport)
      expect(train.connection).to be_a(TrainPlugins::K8sContainer::Connection)
    end
  end

  describe 'Connection with URI' do
    it 'parses URI format correctly' do
      train = Train.create('k8s-container', {
                             path: '/default/test-ubuntu/test-ubuntu',
                           })

      conn = train.connection
      expect(conn.uri).to eq('k8s-container://default/test-ubuntu/test-ubuntu')
    end
  end

  describe 'Platform detection' do
    it 'detects Unix platform family for Ubuntu' do
      conn = TrainPlugins::K8sContainer::Connection.new(
        pod: 'test-ubuntu',
        container_name: 'test-ubuntu',
        namespace: 'default'
      )

      platform = conn.platform
      families = platform.families.keys.map(&:name)

      expect(families).to include('cloud')
      expect(families).to include('container')
      expect(families).to include('unix')
      expect(families).not_to include('windows')
    end

    it 'detects Unix platform family for Alpine' do
      conn = TrainPlugins::K8sContainer::Connection.new(
        pod: 'test-alpine',
        container_name: 'test-alpine',
        namespace: 'default'
      )

      platform = conn.platform
      families = platform.families.keys.map(&:name)

      expect(families).to include('unix')
    end
  end

  describe 'File operations' do
    let(:conn) do
      TrainPlugins::K8sContainer::Connection.new(
        pod: 'test-ubuntu',
        container_name: 'test-ubuntu',
        namespace: 'default'
      )
    end

    it 'checks file existence' do
      file = conn.file('/etc/passwd')
      expect(file.exist?).to be true
    end

    it 'detects missing files' do
      file = conn.file('/nonexistent/path')
      expect(file.exist?).to be false
    end

    it 'reads file content' do
      file = conn.file('/etc/hostname')
      expect(file.exist?).to be true
      expect(file.content).not_to be_empty
    end

    it 'uses correct file handler for Unix' do
      file = conn.file('/etc/passwd')
      expect(file).to be_a(Train::File::Remote::Linux)
    end
  end

  describe 'Command execution with different shells' do
    it 'works with bash (Ubuntu)' do
      conn = TrainPlugins::K8sContainer::Connection.new(
        pod: 'test-ubuntu',
        container_name: 'test-ubuntu'
      )

      result = conn.run_command('echo $SHELL')
      expect(result.exit_status).to eq(0)
      expect(result.stdout).to include('bash')
    end

    it 'works with sh/ash (Alpine)' do
      conn = TrainPlugins::K8sContainer::Connection.new(
        pod: 'test-alpine',
        container_name: 'test-alpine'
      )

      result = conn.run_command('echo test')
      expect(result.exit_status).to eq(0)
      expect(result.stdout.strip).to eq('test')
    end
  end

  describe 'Session pooling performance' do
    it 'reuses sessions across multiple commands' do
      conn = TrainPlugins::K8sContainer::Connection.new(
        pod: 'test-ubuntu',
        container_name: 'test-ubuntu'
      )

      # Execute multiple commands
      5.times do |i|
        result = conn.run_command("echo test#{i}")
        expect(result.stdout.strip).to eq("test#{i}")
      end

      # Should have created and reused one session
      expect(TrainPlugins::K8sContainer::SessionManager.instance.session_count).to be <= 1
    end
  end
end
