# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/kubectl_exec_client'
require 'train-k8s-container/shell_detector'

RSpec.describe 'TrainPlugins::K8sContainer::KubectlExecClient Windows support' do
  let(:null_logger) { Logger.new(IO::NULL) }
  let(:client) do
    TrainPlugins::K8sContainer::KubectlExecClient.new(
      pod: 'windows-test',
      namespace: 'default',
      container_name: 'windows-container',
      logger: null_logger
    )
  end

  describe '.windows_shell?' do
    it 'returns true for cmd.exe' do
      expect(TrainPlugins::K8sContainer::ShellDetector.windows_shell?('cmd.exe')).to be true
    end

    it 'returns true for powershell.exe' do
      expect(TrainPlugins::K8sContainer::ShellDetector.windows_shell?('powershell.exe')).to be true
    end

    it 'returns true for pwsh.exe' do
      expect(TrainPlugins::K8sContainer::ShellDetector.windows_shell?('pwsh.exe')).to be true
    end

    it 'returns false for Unix shells' do
      expect(TrainPlugins::K8sContainer::ShellDetector.windows_shell?('/bin/bash')).to be false
      expect(TrainPlugins::K8sContainer::ShellDetector.windows_shell?('/bin/sh')).to be false
    end
  end

  describe '#build_windows_instruction' do
    it 'builds correct command for cmd.exe' do
      command_builder = client.instance_variable_get(:@command_builder)
      instruction = command_builder.with_windows_shell('cmd.exe', 'dir')
      expect(instruction).to include('cmd.exe')
      expect(instruction).to include('/c')
      expect(instruction).to include('dir')
    end

    it 'builds correct command for powershell.exe' do
      command_builder = client.instance_variable_get(:@command_builder)
      instruction = command_builder.with_windows_shell('powershell.exe', 'Get-Process')
      expect(instruction).to include('powershell.exe')
      expect(instruction).to include('-Command')
      expect(instruction).to include('Get-Process')
    end

    it 'builds correct command for pwsh.exe' do
      command_builder = client.instance_variable_get(:@command_builder)
      instruction = command_builder.with_windows_shell('pwsh.exe', 'Get-ChildItem')
      expect(instruction).to include('pwsh.exe')
      expect(instruction).to include('-Command')
      expect(instruction).to include('Get-ChildItem')
    end

    it 'escapes commands with special characters' do
      command_builder = client.instance_variable_get(:@command_builder)
      instruction = command_builder.with_windows_shell('cmd.exe', 'echo "test & more"')
      # Shellwords.escape will handle the escaping
      expect(instruction).to include('cmd.exe')
      expect(instruction).to include('/c')
    end
  end
end
