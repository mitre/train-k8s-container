# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/kubectl_command_builder'

RSpec.describe TrainPlugins::K8sContainer::KubectlCommandBuilder do
  let(:builder) do
    described_class.new(
      kubectl_path: 'kubectl',
      pod: 'test-pod',
      namespace: 'default',
      container_name: 'nginx'
    )
  end

  describe '#base_command' do
    it 'returns kubectl exec command components' do
      expect(builder.base_command).to eq([
                                           'kubectl', 'exec', '--stdin',
                                           'test-pod', '-n', 'default', '-c', 'nginx',
                                         ])
    end
  end

  describe '#with_shell' do
    it 'builds command for bash' do
      command = builder.with_shell('/bin/bash', 'whoami')
      expect(command).to include('kubectl exec --stdin')
      expect(command).to include('test-pod -n default -c nginx')
      expect(command).to include('-- /bin/bash -c')
      expect(command).to include('whoami')
    end

    it 'escapes special characters in command' do
      command = builder.with_shell('/bin/sh', 'echo $USER && ls')
      expect(command).to include('echo\\ \\$USER\\ \\&\\&\\ ls')
    end
  end

  describe '#with_windows_shell' do
    it 'builds command for cmd.exe' do
      command = builder.with_windows_shell('cmd.exe', 'dir')
      expect(command).to include('kubectl exec --stdin')
      expect(command).to include('test-pod -n default -c nginx')
      expect(command).to include('-- cmd.exe /c')
      expect(command).to include('dir')
    end

    it 'builds command for powershell.exe' do
      command = builder.with_windows_shell('powershell.exe', 'Get-Process')
      expect(command).to include('kubectl exec --stdin')
      expect(command).to include('-- powershell.exe -Command')
      expect(command).to include('Get-Process')
    end

    it 'builds command for pwsh.exe' do
      command = builder.with_windows_shell('pwsh.exe', 'Get-ChildItem')
      expect(command).to include('kubectl exec --stdin')
      expect(command).to include('-- pwsh.exe -Command')
      expect(command).to include('Get-ChildItem')
    end

    it 'escapes special characters in Windows commands' do
      command = builder.with_windows_shell('cmd.exe', 'echo "test & more"')
      expect(command).to include('cmd.exe /c')
      expect(command).to include('\\&')
    end
  end

  describe '#direct_binary' do
    it 'builds command for direct binary execution' do
      command = builder.direct_binary('ls -la')
      expect(command).to include('kubectl exec --stdin')
      expect(command).to include('test-pod -n default -c nginx')
      expect(command).to include('-- ls -la')
    end

    it 'splits command into separate arguments' do
      command = builder.direct_binary('cat /etc/hostname')
      expect(command).to include('cat')
      expect(command).to include('/etc/hostname')
    end
  end

  describe '#with_raw_shell' do
    it 'builds command with hardcoded /bin/sh' do
      command = builder.with_raw_shell('test -x /bin/bash && echo OK')
      expect(command).to include('kubectl exec --stdin')
      expect(command).to include('test-pod -n default -c nginx')
      expect(command).to include('-- /bin/sh -c')
      expect(command).to include('test\\ -x\\ /bin/bash')
    end
  end

  describe '#shell_flag_for' do
    it 'returns /c for cmd.exe' do
      expect(builder.send(:shell_flag_for, 'cmd.exe')).to eq('/c')
    end

    it 'returns -Command for powershell.exe' do
      expect(builder.send(:shell_flag_for, 'powershell.exe')).to eq('-Command')
    end

    it 'returns -Command for pwsh.exe' do
      expect(builder.send(:shell_flag_for, 'pwsh.exe')).to eq('-Command')
    end

    it 'returns -c for unknown shells (Unix default)' do
      expect(builder.send(:shell_flag_for, '/bin/zsh')).to eq('-c')
    end
  end
end
