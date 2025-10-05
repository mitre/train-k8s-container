# frozen_string_literal: true

require 'mixlib/shellout' unless defined?(Mixlib::ShellOut)
require 'shellwords'
require 'logger'
require 'train/options'
require 'train/extras'
require_relative 'retry_handler'
require_relative 'session_manager'
require_relative 'ansi_sanitizer'
require_relative 'kubectl_command_builder'
require_relative 'result_processor'

module TrainPlugins
  module K8sContainer
    # Kubectl exec client for executing commands in Kubernetes containers
    # Supports both one-off execution (Mixlib::ShellOut) and persistent sessions (PTY)
    class KubectlExecClient
      attr_reader :pod, :container_name, :namespace

      DEFAULT_NAMESPACE = 'default'
      DEFAULT_TIMEOUT = 60
      SHELL_DETECTION_TIMEOUT = 5

      def initialize(pod:, namespace: nil, container_name: nil, kubectl_path: 'kubectl', timeout: DEFAULT_TIMEOUT, logger: nil, use_pty: nil)
        @pod = pod
        @container_name = container_name
        @namespace = namespace
        @kubectl_path = kubectl_path
        @timeout = timeout
        @logger = logger || default_logger
        @shell_detector = nil # Will be created lazily
        # Default to enabled (opt-out via use_pty: false or TRAIN_K8S_SESSION_MODE=false)
        @use_pty = use_pty.nil? ? (ENV['TRAIN_K8S_SESSION_MODE'] != 'false') : use_pty
        @pty_fallback_disabled = false
        @command_builder = KubectlCommandBuilder.new(
          kubectl_path: @kubectl_path,
          pod: @pod,
          namespace: @namespace,
          container_name: @container_name
        )
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
        instruction = @command_builder.with_raw_shell(command)
        shell = Mixlib::ShellOut.new(instruction, timeout: SHELL_DETECTION_TIMEOUT)
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

        session = create_pty_session(shell, opts)
        session.execute(command)
      rescue PtySession::SessionClosedError => e
        # Try reconnecting once
        @logger.warn("PTY session closed: #{e.message}, attempting reconnect")
        SessionManager.instance.cleanup_session(session_key)
        session = create_pty_session(shell, opts)
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

          ResultProcessor.process(result, command, @logger)
        end
      end

      def session_key
        "#{@namespace}/#{@pod}/#{@container_name}"
      end

      # Lazy-load and cache shell detector (caching at instance level)
      # ShellDetector also caches detection result internally for efficiency
      # This double-caching prevents both repeated object creation and detection attempts
      def detect_shell
        require_relative 'shell_detector' unless defined?(ShellDetector)
        @shell_detector ||= ShellDetector.new(self)
        @shell_detector.detect
      end

      def execute_with_shell(shell_path, command, opts)
        instruction = if ShellDetector.windows_shell?(shell_path)
                        @command_builder.with_windows_shell(shell_path, command)
                      else
                        @command_builder.with_shell(shell_path, command)
                      end
        shell = Mixlib::ShellOut.new(instruction, timeout: opts[:timeout] || @timeout)
        res = shell.run_command
        Train::Extras::CommandResult.new(res.stdout, res.stderr, res.exitstatus)
      end

      def create_pty_session(shell, opts)
        SessionManager.instance.get_session(
          session_key,
          kubectl_cmd: @command_builder.base_command.join(' '),
          shell: shell,
          timeout: opts[:timeout] || @timeout,
          logger: @logger
        )
      end

      def execute_without_shell(command, opts)
        # For distroless - can only execute simple binaries
        if command.match?(/[|&;<>()$`\\"]/)
          raise ShellNotAvailableError,
                "Container has no shell - cannot execute complex command with operators: #{command}"
        end

        instruction = @command_builder.direct_binary(command)
        shell = Mixlib::ShellOut.new(instruction, timeout: opts[:timeout] || @timeout)
        res = shell.run_command
        Train::Extras::CommandResult.new(res.stdout, res.stderr, res.exitstatus)
      end

      def default_logger
        Logger.new($stdout, level: ENV['TRAIN_K8S_LOG_LEVEL'] || Logger::WARN)
      end
    end
  end
end
