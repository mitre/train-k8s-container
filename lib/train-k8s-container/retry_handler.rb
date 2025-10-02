# frozen_string_literal: true

require_relative 'errors'

module TrainPlugins
  module K8sContainer
    # Handles retry logic with exponential backoff for transient errors
    class RetryHandler
      MAX_RETRIES = 3
      BASE_DELAY = 1 # seconds

      class NetworkError < K8sContainerError; end
      class ConnectionError < K8sContainerError; end

      def self.with_retry(max_retries: MAX_RETRIES, logger: nil)
        retries = 0

        begin
          yield
        rescue NetworkError, ConnectionError => e
          retries += 1
          if retries <= max_retries
            delay = BASE_DELAY * (2**(retries - 1)) # Exponential backoff
            logger&.warn("Transient error (attempt #{retries}/#{max_retries}): #{e.message}, retrying in #{delay}s")
            sleep(delay)
            retry
          else
            logger&.error("Failed after #{max_retries} retries: #{e.message}")
            raise Train::TransportError, "Failed after #{max_retries} retries: #{e.message}"
          end
        end
      end
    end
  end
end
