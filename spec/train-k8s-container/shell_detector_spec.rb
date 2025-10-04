# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/shell_detector'

RSpec.describe TrainPlugins::K8sContainer::ShellDetector do
  let(:kubectl_client) { double('KubectlExecClient') }
  subject { described_class.new(kubectl_client) }

  describe '#detect' do
    context 'when bash is available' do
      before do
        mock_unix_container_with_bash(kubectl_client)
      end

      it 'detects bash' do
        expect(subject.detect).to eq('/bin/bash')
      end

      it 'returns bash shell type' do
        subject.detect
        expect(subject.shell_type).to eq(:bash)
      end

      it 'identifies as unix_container' do
        subject.detect
        expect(subject.unix_container?).to be true
        expect(subject.windows_container?).to be false
      end

      it 'caches the result' do
        subject.detect
        subject.detect # Should not call again
        # Should only call execute_raw once for OS detection (cached after first detect)
        expect(kubectl_client).to have_received(:execute_raw).with('echo test').once
      end
    end

    context 'when only sh is available (Alpine)' do
      before do
        mock_unix_container_with_sh(kubectl_client)
      end

      it 'falls back to sh' do
        expect(subject.detect).to eq('/bin/sh')
      end

      it 'returns sh shell type' do
        subject.detect
        expect(subject.shell_type).to eq(:sh)
      end
    end

    context 'when only ash is available (BusyBox)' do
      before do
        mock_unix_container_with_ash(kubectl_client)
      end

      it 'falls back to ash' do
        expect(subject.detect).to eq('/bin/ash')
      end

      it 'returns ash shell type' do
        subject.detect
        expect(subject.shell_type).to eq(:ash)
      end
    end

    context 'when no shell is available (distroless)' do
      before do
        mock_distroless_container(kubectl_client)
      end

      it 'returns nil' do
        expect(subject.detect).to be_nil
      end

      it 'returns none shell type' do
        subject.detect
        expect(subject.shell_type).to eq(:none)
      end

      it 'sets container_os to unix' do
        subject.detect
        expect(subject.container_os).to eq(:unix)
      end
    end

    context 'when shell detection fails with exception' do
      before do
        mock_shell_detection_error(kubectl_client)
      end

      it 'returns nil' do
        expect(subject.detect).to be_nil
      end
    end

    context 'when cmd.exe is available (Windows container)' do
      before do
        mock_windows_container_with_cmd(kubectl_client)
      end

      it 'detects cmd.exe' do
        expect(subject.detect).to eq('cmd.exe')
      end

      it 'returns cmd shell type' do
        subject.detect
        expect(subject.shell_type).to eq(:cmd)
      end

      it 'identifies as windows_container' do
        subject.detect
        expect(subject.windows_container?).to be true
        expect(subject.unix_container?).to be false
      end
    end
  end

  describe '#shell_available?' do
    context 'when shell exists and is executable' do
      before do
        allow(kubectl_client).to receive(:execute_raw)
          .with('test -x /bin/bash && echo OK')
          .and_return(double(stdout: 'OK', exit_status: 0))
      end

      it 'returns true' do
        expect(subject.shell_available?('/bin/bash')).to be true
      end
    end

    context 'when shell does not exist' do
      before do
        allow(kubectl_client).to receive(:execute_raw)
          .with('test -x /bin/bash && echo OK')
          .and_return(double(stdout: '', exit_status: 1))
      end

      it 'returns false' do
        expect(subject.shell_available?('/bin/bash')).to be false
      end
    end

    context 'when execute_raw raises exception' do
      before do
        allow(kubectl_client).to receive(:execute_raw)
          .and_raise(StandardError)
      end

      it 'returns false' do
        expect(subject.shell_available?('/bin/bash')).to be false
      end
    end
  end
end
