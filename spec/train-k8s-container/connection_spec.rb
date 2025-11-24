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
        # Mock shell detection for file handler selection
        mock_unix_container_with_bash(kube_client)
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
        mock_windows_container_with_cmd(kube_client)
      end

      it 'uses Train::File::Remote::Windows for Windows containers' do
        file = subject.file('C:\\Windows\\System32\\config.ini')
        expect(file).to be_a(Train::File::Remote::Windows)
      end
    end
  end
end
