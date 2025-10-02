# frozen_string_literal: true

require 'mixlib/shellout' unless defined?(Mixlib::ShellOut)
require 'shellwords'
require 'logger'
require 'train/options'
require 'train/extras'
require_relative 'retry_handler'
require_relative 'session_manager'

module TrainPlugins
  module K8sContainer
    # Kubectl exec client for executing commands in Kubernetes containers
    # Supports both one-off execution (Mixlib::ShellOut) and persistent sessions (PTY)
    class KubectlExecClient
      attr_reader :pod, :container_name, :namespace

      DEFAULT_NAMESPACE = 'default'
      DEFAULT_TIMEOUT = 60

      def initialize(pod:, namespace: nil, container_name: nil, kubectl_path: 'kubectl', timeout: DEFAULT_TIMEOUT, logger: nil, use_pty: false)
        @pod = pod
        @container_name = container_name
        @namespace = namespace
        @kubectl_path = kubectl_path
        @timeout = timeout
        @logger = logger || default_logger
        @shell_detector = nil # Will be created lazily
        @use_pty = use_pty || ENV['TRAIN_K8S_PTY_MODE'] == 'true'
        @pty_fallback_disabled = false
      end

      def execute(command, opts = {})
        @logger.debug("Executing command in #{@namespace}/#{@pod}/#{@container_name}: #{command}")

        if @use_pty && pty_available? && !@pty_fallback_disabled
          execute_via_pty(command, opts)
        else
          execute_via_shellout(command, opts)
        end
      rescue Errno::ENOENT => e
        @logger.error("kubectl not found at '#{@kubectl_path}': #{e.message}")
        raise KubectlNotFoundError, "kubectl not found at '#{@kubectl_path}'"
      rescue Mixlib::ShellOut::CommandTimeout
        @logger.error("Command timed out after #{opts[:timeout] || @timeout}s: #{command}")
        raise Train::CommandTimeoutReached, "Command timed out: #{command}"
      end

      # Raw execution for shell detection (uses /bin/sh directly)
      def execute_raw(command)
        instruction = build_raw_instruction(command)
        shell = Mixlib::ShellOut.new(instruction, timeout: 5)
        res = shell.run_command
        Train::Extras::CommandResult.new(res.stdout, res.stderr, res.exitstatus)
      rescue Errno::ENOENT => _e
        Train::Extras::CommandResult.new('', '', 1)
      end

      private

      def pty_available?
        # PTY only works on Unix-like operating systems
        !RUBY_PLATFORM.match?(/windows|mswin|msys|mingw|cygwin/)
      end

      def execute_via_pty(command, opts)
        @logger.debug('Using PTY session for execution')
        shell = detect_shell
        raise ShellNotAvailableError, 'No shell available for PTY mode' unless shell

        session = SessionManager.instance.get_session(
          session_key,
          kubectl_cmd: base_kubectl_command,
          shell: shell,
          timeout: opts[:timeout] || @timeout,
          logger: @logger
        )

        session.execute(command)
      rescue PtySession::SessionClosedError => e
        # Try reconnecting once
        @logger.warn("PTY session closed: #{e.message}, attempting reconnect")
        SessionManager.instance.cleanup_session(session_key)
        session = SessionManager.instance.get_session(
          session_key,
          kubectl_cmd: base_kubectl_command,
          shell: shell,
          timeout: opts[:timeout] || @timeout,
          logger: @logger
        )
        session.execute(command)
      rescue PtySession::PtyError, ShellNotAvailableError => e
        @logger.error("PTY execution failed: #{e.message}, falling back to one-off execution")
        @pty_fallback_disabled = true
        execute_via_shellout(command, opts)
      end

      def execute_via_shellout(command, opts)
        @logger.debug('Using one-off execution (Mixlib::ShellOut)')

        RetryHandler.with_retry(max_retries: opts[:max_retries] || 3, logger: @logger) do
          shell = detect_shell

          result = if shell
                     execute_with_shell(shell, command, opts)
                   else
                     execute_without_shell(command, opts)
                   end

          validate_result(result, command)
          sanitize_result(result)
        end
      end

      def session_key
        "#{@namespace}/#{@pod}/#{@container_name}"
      end

      def base_kubectl_command
        [
          @kubectl_path, 'exec', '--stdin',
          @pod, '-n', @namespace, '-c', @container_name
        ].join(' ')
      end

      def detect_shell
        require_relative 'shell_detector' unless defined?(ShellDetector)
        @shell_detector ||= ShellDetector.new(self)
        @shell_detector.detect
      end

      def execute_with_shell(shell_path, command, opts)
        instruction = build_shell_instruction(shell_path, command)
        shell = Mixlib::ShellOut.new(instruction, timeout: opts[:timeout] || @timeout)
        res = shell.run_command
        Train::Extras::CommandResult.new(res.stdout, res.stderr, res.exitstatus)
      end

      def execute_without_shell(command, opts)
        # For distroless - can only execute simple binaries
        if command.match?(/[|&;<>()$`\\"]/)
          raise ShellNotAvailableError,
                "Container has no shell - cannot execute complex command with operators: #{command}"
        end

        instruction = build_direct_instruction(command)
        shell = Mixlib::ShellOut.new(instruction, timeout: opts[:timeout] || @timeout)
        res = shell.run_command
        Train::Extras::CommandResult.new(res.stdout, res.stderr, res.exitstatus)
      end

      def build_shell_instruction(shell_path, command)
        [
          @kubectl_path, 'exec', '--stdin',
          @pod, '-n', @namespace, '-c', @container_name,
          '--', shell_path, '-c', Shellwords.escape(command)
        ].join(' ')
      end

      def build_direct_instruction(command)
        [
          @kubectl_path, 'exec', '--stdin',
          @pod, '-n', @namespace, '-c', @container_name,
          '--'
        ].concat(command.split).join(' ')
      end

      def build_raw_instruction(command)
        [
          @kubectl_path, 'exec', '--stdin',
          @pod, '-n', @namespace, '-c', @container_name,
          '--', '/bin/sh', '-c', Shellwords.escape(command)
        ].join(' ')
      end

      def validate_result(result, command)
        # Detect silent network failures (kubectl returns exit 0 despite errors)
        if result.exit_status == 0 && result.stdout.empty? && result.stderr.empty? && command_should_produce_output?(command)
          @logger.warn("Silent failure detected for command: #{command}")
          raise RetryHandler::NetworkError, 'Silent failure - no output received'
        end

        # Detect pod/container errors
        if result.stderr.include?('error dialing backend') ||
           result.stderr.include?('connection refused') ||
           result.stderr.include?('not found')
          @logger.warn("Connection error: #{result.stderr}")
          raise RetryHandler::ConnectionError, result.stderr
        end
      end

      def command_should_produce_output?(command)
        # Commands that typically don't produce output
        !command.match?(/^(true|false|touch|mkdir|rm|sleep|test)\b/)
      end

      def sanitize_result(result)
        # Strip ANSI escape sequences for security and reliability
        Train::Extras::CommandResult.new(
          sanitize_output(result.stdout),
          sanitize_output(clean_exit_message(result.stderr)),
          parse_actual_exit_code(result.stderr) || result.exit_status
        )
      end

      def sanitize_output(output)
        return '' if output.nil? || output.empty?

        # Remove ANSI escape sequences
        output.gsub(/\e\[([;\d]+)?[A-Za-z]/, '')
              .gsub(/\e\][^\a]*\a/, '')
              .gsub("\r\n", "\n")
              .gsub("\r", "\n")
      end

      def parse_actual_exit_code(stderr)
        # kubectl sometimes appends: "command terminated with exit code N"
        match = stderr.match(/command terminated with exit code (\d+)/)
        match ? match[1].to_i : nil
      end

      def clean_exit_message(stderr)
        # Remove kubectl's exit code message from stderr
        stderr.gsub(/\ncommand terminated with exit code \d+\s*$/, '')
      end

      def default_logger
        Logger.new($stdout, level: ENV['TRAIN_K8S_LOG_LEVEL'] || Logger::WARN)
      end
    end
  end
end
