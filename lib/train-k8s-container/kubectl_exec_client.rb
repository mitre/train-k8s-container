# frozen_string_literal: true

require 'mixlib/shellout' unless defined?(Mixlib::ShellOut)
require 'shellwords'
require 'train/options'
require 'train/extras'

module TrainPlugins
  module K8sContainer
    # Kubectl exec client for executing commands in Kubernetes containers
    class KubectlExecClient
      attr_reader :pod, :container_name, :namespace

      DEFAULT_NAMESPACE = 'default'
      DEFAULT_TIMEOUT = 60

      def initialize(pod:, namespace: nil, container_name: nil, kubectl_path: 'kubectl', timeout: DEFAULT_TIMEOUT)
        @pod = pod
        @container_name = container_name
        @namespace = namespace
        @kubectl_path = kubectl_path
        @timeout = timeout
        @shell_detector = nil # Will be created lazily
      end

      def execute(command, opts = {})
        shell = detect_shell

        if shell
          execute_with_shell(shell, command, opts)
        else
          execute_without_shell(command, opts)
        end
      rescue Errno::ENOENT => _e
        Train::Extras::CommandResult.new('', 'kubectl command not found', 1)
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
          '--', '/bin/sh', '-c', command
        ].join(' ')
      end
    end
  end
end
