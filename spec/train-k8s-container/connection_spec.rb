# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/connection'

RSpec.describe TrainPlugins::K8sContainer::Connection do
  let(:options) { { pod: 'shell-demo', container_name: 'nginx', namespace: 'default' } }
  let(:kube_client) { double(TrainPlugins::K8sContainer::KubectlExecClient) }
  let(:shell_op) { Train::Extras::CommandResult.new(stdout, stderr, exitstatus) }

  subject { described_class.new(options) }
  let(:stdout) { "Linux\n" }
  let(:stderr) { '' }
  let(:exitstatus) { 0 }
  before do
    allow(TrainPlugins::K8sContainer::KubectlExecClient).to receive(:new).with(**options).and_return(kube_client)
    allow(kube_client).to receive(:execute).with('uname').and_return(shell_op)
  end

  it 'it executes a connect' do
    expect { subject }.not_to raise_error
  end

  context 'when options are not present' do
    context 'when pod parameter is missing' do
      let(:options) { { pod: nil, container_name: 'nginx' } }
      it 'should raise error for missing Pod' do
        expect { subject }.to raise_error(ArgumentError).with_message('Missing Parameter `pod`')
      end
    end

    context 'when container_name parameter is missing' do
      let(:options) { { pod: 'shell-demo' } }
      it 'should raise error for missing Container Name' do
        expect { subject }.to raise_error(ArgumentError).with_message('Missing Parameter `container_name`')
      end
    end
  end

  context 'when namespace is provided as URI host' do
    let(:options) { { host: 'prod', path: '/shell-demo/nginx' } }

    before do
      allow(TrainPlugins::K8sContainer::KubectlExecClient).to receive(:new)
        .with(pod: 'shell-demo', namespace: 'prod', container_name: 'nginx')
        .and_return(kube_client)
    end

    it 'uses the host as the namespace' do
      expect(subject.uri).to eq('k8s-container://prod/shell-demo/nginx')
    end
  end

  context 'when target URI is not pre-expanded' do
    let(:options) { { target: 'k8s-container://prod/shell-demo/nginx' } }

    before do
      allow(TrainPlugins::K8sContainer::KubectlExecClient).to receive(:new)
        .with(pod: 'shell-demo', namespace: 'prod', container_name: 'nginx')
        .and_return(kube_client)
    end

    it 'parses the target URI before connecting' do
      expect(subject.uri).to eq('k8s-container://prod/shell-demo/nginx')
    end
  end

  context 'when namespace is provided as both URI host and explicit option' do
    let(:options) { { host: 'from-uri', namespace: 'from-option', path: '/shell-demo/nginx' } }

    before do
      allow(TrainPlugins::K8sContainer::KubectlExecClient).to receive(:new)
        .with(pod: 'shell-demo', namespace: 'from-option', container_name: 'nginx')
        .and_return(kube_client)
    end

    it 'uses the explicit namespace option over the URI host' do
      expect(subject.uri).to eq('k8s-container://from-option/shell-demo/nginx')
    end
  end

  context 'when target URI uses triple-slash with two path segments' do
    let(:options) { { host: '', path: '/shell-demo/nginx' } }

    before do
      allow(TrainPlugins::K8sContainer::KubectlExecClient).to receive(:new)
        .with(pod: 'shell-demo', namespace: 'default', container_name: 'nginx')
        .and_return(kube_client)
    end

    it 'resolves to the default namespace' do
      expect(subject.uri).to eq('k8s-container://default/shell-demo/nginx')
    end
  end

  context 'when target URI uses triple-slash with three path segments' do
    let(:options) { { host: '', path: '/prod/shell-demo/nginx' } }

    before do
      allow(TrainPlugins::K8sContainer::KubectlExecClient).to receive(:new)
        .with(pod: 'shell-demo', namespace: 'prod', container_name: 'nginx')
        .and_return(kube_client)
    end

    it 'resolves the namespace from the first path segment' do
      expect(subject.uri).to eq('k8s-container://prod/shell-demo/nginx')
    end
  end

  describe '#unique_identifier' do
    it 'delegates to the kubectl client' do
      allow(kube_client).to receive(:unique_identifier).and_return('ns/pod/container')
      expect(subject.unique_identifier).to eq('ns/pod/container')
    end
  end

  context 'when shell detection is shared across operations' do
    let(:stdout) { 'root' }
    let(:kube_client) { TrainPlugins::K8sContainer::KubectlExecClient.new(**options, logger: @null_logger, use_pty: false) }

    before do
      Train::Platforms.__reset
      mock_unix_container_with_bash(kube_client)
      allow(kube_client).to receive(:execute).and_call_original
      allow(kube_client).to receive(:run_shellout).and_return(shell_op)
    end

    after do
      Train::Platforms.__reset
    end

    it 'does not repeat shell probes for platform fallback and file handling' do
      expect(subject.run_command('whoami').stdout).to eq('root')
      expect(subject.send(:fallback_platform).linux?).to be true
      expect(subject.file('/etc/passwd')).to be_a(Train::File::Remote::Linux)

      expect(kube_client).to have_received(:execute_raw).with('echo test').once
      expect(kube_client).to have_received(:execute_raw).with('cat /etc/os-release 2>/dev/null').once
      expect(kube_client).to have_received(:execute_raw).with('test -x /bin/bash && echo OK').once
    end
  end

  describe '#file' do
    context 'path validation' do
      it 'rejects nil path' do
        expect { subject.file(nil) }.to raise_error(ArgumentError, /cannot be nil/)
      end

      it 'rejects empty path' do
        expect { subject.file('') }.to raise_error(ArgumentError, /cannot be empty/)
      end
    end

    context 'on Unix containers' do
      let(:proc_version) do
        'Linux version 6.5.11-linuxkit (root@buildkitsandbox) ' \
          '(gcc (Alpine 12.2.1_git20220924-r10) 12.2.1 20220924, GNU ld (GNU Binutils) 2.40) ' \
          "#1 SMP PREEMPT Wed Dec  6 17:08:31 UTC 2023\n"
      end
      let(:stdout) { proc_version }
      before do
        allow(kube_client).to receive(:container_os).and_return(:unix)
        allow(kube_client).to receive(:execute).with('cat /proc/version || echo -n').and_return(shell_op)
      end

      it 'uses Train::File::Remote::Linux for Unix containers' do
        file = subject.file('/proc/version')
        expect(file).to be_a(Train::File::Remote::Linux)
      end

      it 'executes a file connection' do
        expect(subject.file('/proc/version').content).to eq(stdout)
      end
    end

    context 'on Windows containers' do
      before do
        allow(kube_client).to receive(:container_os).and_return(:windows)
      end

      it 'uses Train::File::Remote::Windows for Windows containers' do
        file = subject.file('C:\\Windows\\System32\\config.ini')
        expect(file).to be_a(Train::File::Remote::Windows)
      end
    end

    context 'when the container OS is unknown' do
      before do
        allow(kube_client).to receive(:container_os).and_return(:unknown)
      end

      it 'uses Train::File::Remote::Linux' do
        expect(subject.file('/etc/passwd')).to be_a(Train::File::Remote::Linux)
      end
    end
  end
end
