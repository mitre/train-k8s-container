# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/shell_detector'

RSpec.describe TrainPlugins::K8sContainer::ShellDetector do
  let(:kubectl_client) { double('KubectlExecClient') }
  subject { described_class.new(kubectl_client) }

  describe '#detect' do
    context 'when bash is available' do
      before do
        allow(kubectl_client).to receive(:execute_raw)
          .with('test -x /bin/bash && echo OK')
          .and_return(double(stdout: 'OK', exit_status: 0))
      end

      it 'detects bash' do
        expect(subject.detect).to eq('/bin/bash')
      end

      it 'returns bash shell type' do
        subject.detect
        expect(subject.shell_type).to eq(:bash)
      end

      it 'caches the result' do
        subject.detect
        expect(kubectl_client).to have_received(:execute_raw).once
        subject.detect # Should not call again
        expect(kubectl_client).to have_received(:execute_raw).once
      end
    end

    context 'when only sh is available (Alpine)' do
      before do
        allow(kubectl_client).to receive(:execute_raw)
          .with('test -x /bin/bash && echo OK')
          .and_return(double(stdout: '', exit_status: 1))
        allow(kubectl_client).to receive(:execute_raw)
          .with('test -x /bin/sh && echo OK')
          .and_return(double(stdout: 'OK', exit_status: 0))
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
        allow(kubectl_client).to receive(:execute_raw)
          .with('test -x /bin/bash && echo OK')
          .and_return(double(stdout: '', exit_status: 1))
        allow(kubectl_client).to receive(:execute_raw)
          .with('test -x /bin/sh && echo OK')
          .and_return(double(stdout: '', exit_status: 1))
        allow(kubectl_client).to receive(:execute_raw)
          .with('test -x /bin/ash && echo OK')
          .and_return(double(stdout: 'OK', exit_status: 0))
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
        allow(kubectl_client).to receive(:execute_raw)
          .and_return(double(stdout: '', exit_status: 1))
      end

      it 'returns nil' do
        expect(subject.detect).to be_nil
      end

      it 'returns none shell type' do
        subject.detect
        expect(subject.shell_type).to eq(:none)
      end
    end

    context 'when shell detection fails with exception' do
      before do
        allow(kubectl_client).to receive(:execute_raw)
          .and_raise(StandardError.new('Connection error'))
      end

      it 'returns nil' do
        expect(subject.detect).to be_nil
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
