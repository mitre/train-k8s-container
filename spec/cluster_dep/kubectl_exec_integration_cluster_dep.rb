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

  describe 'shell detection' do
    it 'detects bash in Ubuntu containers' do
      shell = ubuntu_client.send(:detect_shell)
      expect(shell).to eq('/bin/bash')
    end

    it 'detects sh/ash in Alpine containers' do
      shell = alpine_client.send(:detect_shell)
      expect(['/bin/sh', '/bin/ash']).to include(shell)
    end
  end

  describe 'command execution (shellout mode)' do
    it 'executes simple commands' do
      result = ubuntu_client.execute('whoami')
      expect(result.exit_status).to eq(0)
      expect(result.stdout.strip).to eq('root')
    end

    it 'handles command failures' do
      result = ubuntu_client.execute('nonexistent-command')
      expect(result.exit_status).not_to eq(0)
      expect(result.stderr).to include('not found')
    end

    it 'handles commands with special characters' do
      result = ubuntu_client.execute('echo "test & more"')
      expect(result.exit_status).to eq(0)
      expect(result.stdout).to include('test & more')
    end

    it 'handles multi-line output' do
      result = ubuntu_client.execute('printf "line1\\nline2\\nline3"')
      expect(result.stdout.lines.count).to eq(3)
    end
  end

  describe 'command execution (PTY mode)' do
    it 'executes commands via PTY' do
      result = ubuntu_client_pty.execute('whoami')
      expect(result.exit_status).to eq(0)
      expect(result.stdout.strip).to eq('root')
    end

    it 'maintains session across commands' do
      result1 = ubuntu_client_pty.execute('export TEST_VAR=hello')
      result2 = ubuntu_client_pty.execute('echo $TEST_VAR')

      expect(result1.exit_status).to eq(0)
      expect(result2.stdout.strip).to eq('hello')
    end

    it 'handles rapid sequential commands' do
      results = 10.times.map do |i|
        ubuntu_client_pty.execute("echo test#{i}")
      end

      results.each_with_index do |result, i|
        expect(result.exit_status).to eq(0)
        expect(result.stdout.strip).to eq("test#{i}")
      end
    end
  end

  describe 'error handling' do
    it 'provides helpful error for missing pod' do
      bad_client = TrainPlugins::K8sContainer::KubectlExecClient.new(
        pod: 'nonexistent-pod',
        container_name: 'test',
        namespace: 'default'
      )

      expect do
        bad_client.execute('whoami')
      end.to raise_error(/not found|NotFound/)
    end

    it 'provides helpful error for missing container' do
      bad_client = TrainPlugins::K8sContainer::KubectlExecClient.new(
        pod: 'test-ubuntu',
        container_name: 'nonexistent-container',
        namespace: 'default'
      )

      expect do
        bad_client.execute('whoami')
      end.to raise_error(/not valid|container/)
    end
  end

  describe 'ANSI sanitization' do
    it 'removes ANSI sequences from output' do
      # Some commands in containers produce ANSI sequences
      result = ubuntu_client.execute('ls --color=always /etc | head -3')

      # Output should not contain ANSI color codes
      expect(result.stdout).not_to match(/\e\[/)
    end
  end
end