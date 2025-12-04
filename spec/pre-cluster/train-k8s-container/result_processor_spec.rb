# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/result_processor'
require 'logger'

RSpec.describe TrainPlugins::K8sContainer::ResultProcessor do
  let(:logger) { Logger.new(IO::NULL) }

  describe '.process' do
    it 'validates and sanitizes successful result' do
      result = double('result',
                      exit_status: 0,
                      stdout: "test output\n",
                      stderr: '')

      processed = described_class.process(result, 'whoami', logger)
      expect(processed).to be_a(Train::Extras::CommandResult)
      expect(processed.stdout).to eq("test output\n")
      expect(processed.exit_status).to eq(0)
    end

    it 'raises NetworkError on silent failure' do
      result = double('result',
                      exit_status: 0,
                      stdout: '',
                      stderr: '')

      expect do
        described_class.process(result, 'whoami', logger)
      end.to raise_error(TrainPlugins::K8sContainer::RetryHandler::NetworkError)
    end

    it 'raises ConnectionError on connection errors' do
      result = double('result',
                      exit_status: 1,
                      stdout: '',
                      stderr: 'error dialing backend')

      expect do
        described_class.process(result, 'whoami', logger)
      end.to raise_error(TrainPlugins::K8sContainer::RetryHandler::ConnectionError)
    end
  end

  describe '.validate' do
    it 'passes valid result' do
      result = double('result',
                      exit_status: 0,
                      stdout: 'output',
                      stderr: '')

      expect do
        described_class.validate(result, 'whoami', logger)
      end.not_to raise_error
    end

    it 'allows silent commands to have no output' do
      result = double('result',
                      exit_status: 0,
                      stdout: '',
                      stderr: '')

      expect do
        described_class.validate(result, 'true', logger)
      end.not_to raise_error
    end

    it 'detects silent failure for commands that should produce output' do
      result = double('result',
                      exit_status: 0,
                      stdout: '',
                      stderr: '')

      expect do
        described_class.validate(result, 'whoami', logger)
      end.to raise_error(TrainPlugins::K8sContainer::RetryHandler::NetworkError, /Silent failure/)
    end

    it 'detects connection refused error' do
      result = double('result',
                      exit_status: 1,
                      stdout: '',
                      stderr: 'connection refused')

      expect do
        described_class.validate(result, 'whoami', logger)
      end.to raise_error(TrainPlugins::K8sContainer::RetryHandler::ConnectionError)
    end

    it 'detects pod not found error' do
      result = double('result',
                      exit_status: 1,
                      stdout: '',
                      stderr: 'Error from server (NotFound): pods "test-pod" not found')

      expect do
        described_class.validate(result, 'whoami', logger)
      end.to raise_error(TrainPlugins::K8sContainer::RetryHandler::ConnectionError)
    end

    it 'detects error dialing backend' do
      result = double('result',
                      exit_status: 1,
                      stdout: '',
                      stderr: 'error dialing backend: some error')

      expect do
        described_class.validate(result, 'whoami', logger)
      end.to raise_error(TrainPlugins::K8sContainer::RetryHandler::ConnectionError)
    end
  end

  describe '.sanitize' do
    it 'removes ANSI sequences from stdout and stderr' do
      result = double('result',
                      stdout: "\e[31mRed\e[0m",
                      stderr: "\e[32mGreen\e[0m",
                      exit_status: 0)

      sanitized = described_class.sanitize(result)
      expect(sanitized.stdout).to eq('Red')
      expect(sanitized.stderr).to eq('Green')
    end

    it 'parses exit code from kubectl stderr message' do
      result = double('result',
                      stdout: '',
                      stderr: "some error\ncommand terminated with exit code 42",
                      exit_status: 0)

      sanitized = described_class.sanitize(result)
      expect(sanitized.exit_status).to eq(42)
    end

    it 'uses result exit status when no kubectl message present' do
      result = double('result',
                      stdout: '',
                      stderr: 'error',
                      exit_status: 1)

      sanitized = described_class.sanitize(result)
      expect(sanitized.exit_status).to eq(1)
    end

    it 'cleans exit message from stderr' do
      result = double('result',
                      stdout: '',
                      stderr: "actual error\ncommand terminated with exit code 1",
                      exit_status: 1)

      sanitized = described_class.sanitize(result)
      expect(sanitized.stderr).to eq("actual error\n")
    end
  end

  describe '.should_produce_output?' do
    it 'returns false for silent commands' do
      TrainPlugins::K8sContainer::ResultProcessor::SILENT_COMMANDS.each do |cmd|
        expect(described_class.should_produce_output?(cmd)).to be false
      end
    end

    it 'returns true for commands that should produce output' do
      expect(described_class.should_produce_output?('whoami')).to be true
      expect(described_class.should_produce_output?('ls -la')).to be true
      expect(described_class.should_produce_output?('cat /etc/hostname')).to be true
    end

    it 'checks command prefix, not contains' do
      expect(described_class.should_produce_output?('echo test')).to be true
      expect(described_class.should_produce_output?('ls test')).to be true
    end
  end

  describe '.parse_exit_code' do
    it 'parses exit code from kubectl message' do
      stderr = "some output\ncommand terminated with exit code 42"
      expect(described_class.parse_exit_code(stderr)).to eq(42)
    end

    it 'returns nil when no kubectl message present' do
      stderr = 'some error message'
      expect(described_class.parse_exit_code(stderr)).to be_nil
    end

    it 'handles exit code 0' do
      stderr = 'command terminated with exit code 0'
      expect(described_class.parse_exit_code(stderr)).to eq(0)
    end
  end

  describe '.clean_exit_message' do
    it 'removes kubectl exit message' do
      stderr = "actual error\ncommand terminated with exit code 1"
      expect(described_class.clean_exit_message(stderr)).to eq("actual error\n")
    end

    it 'leaves stderr unchanged when no kubectl message' do
      stderr = 'just an error'
      expect(described_class.clean_exit_message(stderr)).to eq('just an error')
    end

    it 'handles multiple newlines' do
      stderr = "error1\nerror2\ncommand terminated with exit code 1"
      expect(described_class.clean_exit_message(stderr)).to eq("error1\nerror2\n")
    end
  end

  describe 'CONST

ANTS' do
    it 'defines CONNECTION_ERROR_PATTERNS' do
      expect(described_class::CONNECTION_ERROR_PATTERNS).to be_frozen
      expect(described_class::CONNECTION_ERROR_PATTERNS).to include('error dialing backend')
      expect(described_class::CONNECTION_ERROR_PATTERNS).to include('connection refused')
      expect(described_class::CONNECTION_ERROR_PATTERNS).to include('pods "')
      expect(described_class::CONNECTION_ERROR_PATTERNS).to include('Error from server')
    end

    it 'defines SILENT_COMMANDS' do
      expect(described_class::SILENT_COMMANDS).to be_frozen
      expect(described_class::SILENT_COMMANDS).to include('true', 'false', 'test')
    end
  end
end
