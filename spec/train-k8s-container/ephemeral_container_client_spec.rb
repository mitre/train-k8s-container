# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/ephemeral_container_client'

RSpec.describe TrainPlugins::K8sContainer::EphemeralContainerClient do
  let(:commands) { [] }
  let(:result) { Struct.new(:stdout, :stderr, :exitstatus) }

  before do
    allow(Mixlib::ShellOut).to receive(:new) do |command, **_opts|
      commands << command
      response = if command.include?(' debug ')
                   result.new('', '', 0)
                 elsif command.include?(' get pod ')
                   result.new('', '', 0)
                 elsif command.include?('echo') && command.include?('ready')
                   result.new("ready\n", '', 0)
                 elsif command.include?('stat\\ -Lc')
                   result.new('', '', 0)
                 else
                   result.new('ID=debian', '', 0)
                 end
      double(run_command: response)
    end
  end

  it 'adds one named debug container and executes in the target root' do
    client = described_class.new(pod: 'app', namespace: 'default', target_container_name: 'main')
    expect(client.execute('cat /etc/os-release | grep ID').stdout).to eq('ID=debian')
    expect(client.unique_identifier).to eq('default/app/main')

    expect(commands.grep(/ debug /).length).to eq(1)
    expect(commands.grep(/ debug /).first).to include('--target\=main', '--image\=busybox:1.36-musl',
                                                    '--profile\=general', '--attach\=false')
    shell_script = Shellwords.split(commands.last).last
    expect(shell_script).to include('chroot /proc/1/root', 'cat\\ /etc/os-release\\ \\|\\ grep\\ ID')
    expect(shell_script).to end_with('; status=$?; exit "$status"')
  end

  it 'reports a failure to create an ephemeral container' do
    allow(Mixlib::ShellOut).to receive(:new) do |command, **_opts|
      response = command.include?(' debug ') ? result.new('', 'forbidden', 1) : result.new('', '', 0)
      double(run_command: response)
    end
    expect do
      described_class.new(pod: 'app', namespace: 'default', target_container_name: 'main')
    end.to raise_error(TrainPlugins::K8sContainer::EphemeralContainerError, /forbidden/)
  end

  it 'rejects a shared process namespace before creating a helper' do
    allow(Mixlib::ShellOut).to receive(:new) do |command, **_opts|
      commands << command
      response = command.include?(' get pod ') ? result.new('true', '', 0) : result.new('', '', 0)
      double(run_command: response)
    end
    expect do
      described_class.new(pod: 'app', namespace: 'default', target_container_name: 'main')
    end.to raise_error(TrainPlugins::K8sContainer::EphemeralContainerError, /shareProcessNamespace/)
    expect(commands.grep(/ debug /)).to be_empty
  end

  it 'rejects a debug container that cannot see the target process namespace' do
    allow(Mixlib::ShellOut).to receive(:new) do |command, **_opts|
      response = if command.include?('stat\\ -Lc')
                   result.new('', '', 1)
                 elsif command.include?('echo') && command.include?('ready')
                   result.new('ready', '', 0)
                 else
                   result.new('', '', 0)
                 end
      double(run_command: response)
    end
    expect do
      described_class.new(pod: 'app', namespace: 'default', target_container_name: 'main')
    end.to raise_error(TrainPlugins::K8sContainer::EphemeralContainerError, /process namespace sharing/)
  end

  it 'reports when the helper cannot chroot into the target' do
    allow(Mixlib::ShellOut).to receive(:new) do |command, **_opts|
      response = if command.include?('chroot')
                   result.new('', 'Operation not permitted', 1)
                 elsif command.include?('echo') && command.include?('ready')
                   result.new('ready', '', 0)
                 else
                   result.new('', '', 0)
                 end
      double(run_command: response)
    end
    expect do
      described_class.new(pod: 'app', namespace: 'default', target_container_name: 'main')
    end.to raise_error(TrainPlugins::K8sContainer::EphemeralContainerError, /Operation not permitted/)
  end
end
