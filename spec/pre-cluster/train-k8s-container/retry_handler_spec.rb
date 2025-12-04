# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/retry_handler'

RSpec.describe TrainPlugins::K8sContainer::RetryHandler do
  let(:logger) { Logger.new(IO::NULL) }

  describe '.with_retry' do
    it 'returns result on successful first attempt' do
      result = described_class.with_retry(logger: logger) do
        'success'
      end

      expect(result).to eq('success')
    end

    it 'retries on NetworkError' do
      attempt = 0
      result = described_class.with_retry(max_retries: 2, logger: logger) do
        attempt += 1
        raise TrainPlugins::K8sContainer::RetryHandler::NetworkError, 'network error' if attempt == 1

        'success'
      end

      expect(result).to eq('success')
      expect(attempt).to eq(2)
    end

    it 'retries on ConnectionError' do
      attempt = 0
      result = described_class.with_retry(max_retries: 2, logger: logger) do
        attempt += 1
        raise TrainPlugins::K8sContainer::RetryHandler::ConnectionError, 'connection error' if attempt == 1

        'success'
      end

      expect(result).to eq('success')
      expect(attempt).to eq(2)
    end

    it 'uses exponential backoff' do
      attempt = 0
      delays = []

      allow_any_instance_of(Object).to receive(:sleep) do |_, delay|
        delays << delay
      end

      described_class.with_retry(max_retries: 3, logger: logger) do
        attempt += 1
        raise TrainPlugins::K8sContainer::RetryHandler::NetworkError, 'error' if attempt <= 3

        'success'
      end

      # Exponential backoff: 1, 2, 4 seconds
      expect(delays).to eq([1, 2, 4])
    end

    it 'raises Train::TransportError after max retries exceeded' do
      attempt = 0

      expect do
        described_class.with_retry(max_retries: 2, logger: logger) do
          attempt += 1
          raise TrainPlugins::K8sContainer::RetryHandler::NetworkError, 'persistent error'
        end
      end.to raise_error(Train::TransportError, /Failed after 2 retries/)

      expect(attempt).to eq(3) # Initial + 2 retries
    end

    it 'does not retry on non-retryable errors' do
      attempt = 0

      expect do
        described_class.with_retry(max_retries: 3, logger: logger) do
          attempt += 1
          raise ArgumentError, 'invalid argument'
        end
      end.to raise_error(ArgumentError, /invalid argument/)

      expect(attempt).to eq(1) # Should not retry
    end

    it 'respects custom max_retries' do
      attempt = 0

      expect do
        described_class.with_retry(max_retries: 5, logger: logger) do
          attempt += 1
          raise TrainPlugins::K8sContainer::RetryHandler::NetworkError, 'error'
        end
      end.to raise_error(Train::TransportError)

      expect(attempt).to eq(6) # Initial + 5 retries
    end

    it 'logs warnings on retry' do
      attempt = 0
      log_output = StringIO.new
      test_logger = Logger.new(log_output)

      described_class.with_retry(max_retries: 1, logger: test_logger) do
        attempt += 1
        raise TrainPlugins::K8sContainer::RetryHandler::NetworkError, 'network issue' if attempt == 1

        'success'
      end

      expect(log_output.string).to include('Transient error')
      expect(log_output.string).to include('network issue')
      expect(log_output.string).to include('retrying in 1s')
    end

    it 'logs error on final failure' do
      log_output = StringIO.new
      test_logger = Logger.new(log_output)

      expect do
        described_class.with_retry(max_retries: 1, logger: test_logger) do
          raise TrainPlugins::K8sContainer::RetryHandler::ConnectionError, 'connection refused'
        end
      end.to raise_error(Train::TransportError)

      expect(log_output.string).to include('Failed after 1 retries')
      expect(log_output.string).to include('connection refused')
    end
  end

  describe 'constants' do
    it 'defines MAX_RETRIES' do
      expect(described_class::MAX_RETRIES).to eq(3)
    end

    it 'defines BASE_DELAY' do
      expect(described_class::BASE_DELAY).to eq(1)
    end
  end

  describe 'error classes' do
    it 'defines NetworkError' do
      expect(described_class::NetworkError.ancestors).to include(TrainPlugins::K8sContainer::K8sContainerError)
    end

    it 'defines ConnectionError' do
      expect(described_class::ConnectionError.ancestors).to include(TrainPlugins::K8sContainer::K8sContainerError)
    end
  end
end
