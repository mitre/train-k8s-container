# frozen_string_literal: true

require_relative 'ansi_sanitizer'
require_relative 'retry_handler'

module TrainPlugins
  module K8sContainer
    # Processes kubectl command results: validation, sanitization, exit code parsing
    # Consolidates result processing logic for cleaner separation of concerns
    class ResultProcessor
      # Connection error patterns that trigger retries
      # Note: Be specific to avoid false positives (e.g., "command not found" is NOT a connection error)
      CONNECTION_ERROR_PATTERNS = [
        'error dialing backend',
        'connection refused',
        'pods "',           # "pods \"name\" not found" - kubectl can't find pod
        'namespaces "',     # "namespaces \"name\" not found" - kubectl can't find namespace
        'Error from server', # kubectl API errors
      ].freeze

      # Commands that don't produce output (used for silent failure detection)
      SILENT_COMMANDS = %w[true false touch mkdir rm sleep test].freeze

      # Process a command result: validate, sanitize, and return Train::Extras::CommandResult
      # @param result [Mixlib::ShellOut::Result] The raw command result
      # @param command [String] The command that was executed
      # @param logger [Logger] Logger instance for warnings
      # @return [Train::Extras::CommandResult] Processed result
      # @raise [RetryHandler::NetworkError] On silent failures
      # @raise [RetryHandler::ConnectionError] On connection errors
      def self.process(result, command, logger)
        validate(result, command, logger)
        sanitize(result)
      end

      # Validate result for connection errors and silent failures
      # @param result [Object] Result with exit_status, stdout, stderr
      # @param command [String] The command that was executed
      # @param logger [Logger] Logger instance
      # @raise [RetryHandler::NetworkError] On silent failures
      # @raise [RetryHandler::ConnectionError] On connection errors
      def self.validate(result, command, logger)
        # Detect silent network failures (kubectl returns exit 0 despite errors)
        if result.exit_status.zero? && result.stdout.empty? && result.stderr.empty? && should_produce_output?(command)
          logger.warn("Silent failure detected for command: #{command}")
          raise RetryHandler::NetworkError, 'Silent failure - no output received'
        end

        # Check for connection-related errors in stderr
        if CONNECTION_ERROR_PATTERNS.any? { |pattern| result.stderr.include?(pattern) }
          logger.warn("Connection error: #{result.stderr}")
          raise RetryHandler::ConnectionError, result.stderr
        end

        result
      end

      # Sanitize result: remove ANSI sequences, parse exit codes
      # @param result [Object] Result with stdout, stderr, exit_status
      # @return [Train::Extras::CommandResult] Sanitized result
      def self.sanitize(result)
        Train::Extras::CommandResult.new(
          AnsiSanitizer.sanitize(result.stdout),
          AnsiSanitizer.sanitize(clean_exit_message(result.stderr)),
          parse_exit_code(result.stderr) || result.exit_status
        )
      end

      # Check if a command should produce output
      # @param command [String] The command to check
      # @return [Boolean] True if command should produce output
      def self.should_produce_output?(command)
        SILENT_COMMANDS.none? { |cmd| command.start_with?(cmd) }
      end

      # Parse actual exit code from kubectl's stderr message
      # kubectl sometimes appends: "command terminated with exit code N"
      # @param stderr [String] stderr output from kubectl
      # @return [Integer, nil] Parsed exit code or nil
      def self.parse_exit_code(stderr)
        match = stderr.match(/command terminated with exit code (\d+)/)
        match[1].to_i if match
      end

      # Clean kubectl's exit message from stderr
      # @param stderr [String] stderr output from kubectl
      # @return [String] Cleaned stderr without kubectl messages
      def self.clean_exit_message(stderr)
        # Remove kubectl's "command terminated with exit code" message
        stderr.gsub(/command terminated with exit code \d+\n?/, '')
      end
    end
  end
end
