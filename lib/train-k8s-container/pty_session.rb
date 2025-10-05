# frozen_string_literal: true

require 'pty'
require 'timeout'
require_relative 'errors'
require_relative 'ansi_sanitizer'

module TrainPlugins
  module K8sContainer
    # PTY-based persistent shell session for performance optimization
    # Maintains a single kubectl exec session instead of spawning per command
    class PtySession
      class PtyError < K8sContainerError; end
      class SessionClosedError < PtyError; end
      class CommandTimeoutError < PtyError; end

      attr_reader :session_key, :reader, :writer, :pid

      DEFAULT_COMMAND_TIMEOUT = 60
      DEFAULT_SESSION_TIMEOUT = 300

      def initialize(session_key:, kubectl_cmd:, shell: '/bin/bash', timeout: DEFAULT_SESSION_TIMEOUT, logger: nil)
        @session_key = session_key
        @kubectl_cmd = kubectl_cmd
        @shell = shell
        @timeout = timeout
        @command_timeout = DEFAULT_COMMAND_TIMEOUT
        # Logger is optional - all logging uses safe navigation (@logger&.method)
        @logger = logger
        @reader = nil
        @writer = nil
        @pid = nil
      end

      def connect
        raise SessionClosedError, 'Session already connected' if connected?

        @logger&.debug("Opening persistent session for #{@session_key} with #{@shell}")
        @reader, @writer, @pid = PTY.spawn("#{@kubectl_cmd} -- #{@shell}")
        @writer.sync = true

        # Wait briefly for shell to be ready (no prompt expected without --tty)
        sleep(0.1)

        @logger&.debug("Persistent session established (PID: #{@pid})")
        true
      rescue StandardError => e
        cleanup
        raise PtyError, "Failed to connect: #{e.message}"
      end

      def connected?
        @reader && @writer && !@reader.closed? && !@writer.closed?
      end

      def healthy?
        return false unless connected?

        begin
          Process.kill(0, @pid)
          true
        rescue Errno::ESRCH
          false
        end
      end

      def execute(command)
        raise SessionClosedError, 'Session not connected' unless connected?
        raise SessionClosedError, 'Session unhealthy' unless healthy?

        @logger&.debug("Executing in PTY session: #{command}")

        # Send command with exit code marker
        cmd_with_marker = "#{command} 2>&1 ; echo __EXIT_CODE__=$?"
        @writer.puts(cmd_with_marker)
        @writer.flush

        # Read output until exit code marker
        output = read_until_marker
        parse_output(output, command)
      rescue Errno::EIO => e
        raise SessionClosedError, "Connection lost: #{e.message}"
      rescue Timeout::Error
        raise CommandTimeoutError, "Command timed out after #{@command_timeout}s"
      end

      def disconnect
        return unless connected?

        @logger&.debug("Closing PTY session #{@session_key}")
        begin
          @writer.puts 'exit' unless @writer.closed?
          @writer.close unless @writer.closed?
          @reader.close unless @reader.closed?
          Process.wait(@pid, Process::WNOHANG)
        rescue StandardError => e
          @logger&.warn("Error during disconnect: #{e.message}")
        ensure
          @reader = nil
          @writer = nil
          @pid = nil
        end
      end

      alias cleanup disconnect

      private

      def read_until_marker
        buffer = +'' # Unfreeze string

        Timeout.timeout(@command_timeout) do
          while (line = @reader.gets)
            buffer << line
            break if line =~ /__EXIT_CODE__=(\d+)/
          end
        end

        buffer
      end

      def parse_output(buffer, command)
        # Strip ANSI sequences
        cleaned = strip_ansi_sequences(buffer)

        # Extract exit code
        exit_code = 1
        if (match = cleaned.match(/__EXIT_CODE__=(\d+)/))
          exit_code = match[1].to_i
        end

        # Remove exit code line
        cleaned = cleaned.gsub(/__EXIT_CODE__=\d+.*$/, '')

        # Split into lines and remove command echo
        lines = cleaned.lines
        # Remove command wrapper echo (exact match)
        cmd_wrapper = "#{command} 2>&1 ; echo __EXIT_CODE__=$?"
        lines.reject! { |l| l.strip == cmd_wrapper.strip || l.strip == command.strip }

        output = lines.join

        # Separate stdout/stderr based on exit code
        if exit_code.zero?
          Train::Extras::CommandResult.new(output.strip, '', exit_code)
        else
          Train::Extras::CommandResult.new('', output.strip, exit_code)
        end
      end

      def strip_ansi_sequences(text)
        AnsiSanitizer.sanitize(text)
      end
    end
  end
end
