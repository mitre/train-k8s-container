# frozen_string_literal: true

require 'securerandom'
require 'shellwords'
require_relative 'errors'
require_relative 'kubectl_exec_client'

module TrainPlugins
  module K8sContainer
    # Runs BusyBox tools against the target container's root filesystem.
    # The target process namespace must be shared by the container runtime.
    class EphemeralContainerClient < KubectlExecClient
      START_TIMEOUT = 60
      READY_ATTEMPTS = 60

      def initialize(pod:, namespace:, target_container_name:, image: 'busybox:1.36-musl', kubectl_path: 'kubectl', logger: nil)
        @target_container_name = target_container_name
        debug_name = "inspec-#{SecureRandom.hex(5)}"
        super(pod:, namespace:, container_name: debug_name, kubectl_path:, logger:, use_pty: false)
        validate_process_namespace
        start_debug_container(image)
        wait_until_ready
        verify_target_root
      end

      def execute(command, opts = {})
        RetryHandler.with_retry(max_retries: opts[:max_retries] || 3, logger: @logger) do
          result = run_target_command(command, timeout: opts[:timeout] || DEFAULT_TIMEOUT)
          ResultProcessor.process(result, command, @logger)
        end
      rescue Mixlib::ShellOut::CommandTimeout
        raise Train::CommandTimeoutReached, "Command timed out: #{command}"
      rescue Errno::ENOENT
        raise KubectlNotFoundError, "kubectl not found at '#{@kubectl_path}'"
      end

      def execute_raw(command)
        run_target_command(command, timeout: SHELL_DETECTION_TIMEOUT)
      end

      # Preserve the identity of the container being scanned in Train reports.
      def unique_identifier
        "#{namespace}/#{pod}/#{@target_container_name}"
      end

      private

      def validate_process_namespace
        command = [
          @kubectl_path, 'get', 'pod', pod, '-n', namespace,
          '-o', 'jsonpath={.spec.shareProcessNamespace}',
        ].map { |part| Shellwords.escape(part) }.join(' ')
        result = run_shellout(command, timeout: SHELL_DETECTION_TIMEOUT)
        unless result.exit_status.zero?
          raise EphemeralContainerError, "Cannot inspect #{unique_identifier}: #{result.stderr.strip}"
        end
        return unless result.stdout.strip == 'true'

        raise EphemeralContainerError,
              "Cannot scan #{unique_identifier} with an ephemeral container: " \
              'pods with shareProcessNamespace enabled do not place the target process at PID 1'
      end

      def start_debug_container(image)
        command = [
          @kubectl_path, 'debug', pod, '-n', namespace,
          "--container=#{container_name}", "--image=#{image}",
          "--target=#{@target_container_name}", '--profile=general', '--attach=false',
          '--', 'sleep', '2147483647',
        ].map { |part| Shellwords.escape(part) }.join(' ')
        result = run_shellout(command, timeout: START_TIMEOUT)
        return if result.exit_status.zero?

        raise EphemeralContainerError,
              "Unable to add ephemeral container to #{unique_identifier}: #{result.stderr.strip}"
      end

      def wait_until_ready
        READY_ATTEMPTS.times do
          result = run_shellout(@command_builder.with_raw_shell('echo ready'), timeout: SHELL_DETECTION_TIMEOUT)
          return if result.exit_status.zero? && result.stdout.strip == 'ready'

          sleep 1
        end
        raise EphemeralContainerError, "Ephemeral container #{container_name} did not become ready in #{unique_identifier}"
      end

      def verify_target_root
        # An isolated debug container sees its own sleep process as PID 1.
        # In that case /proc/1/root would silently scan the debug image.
        instruction = @command_builder.with_raw_shell(
          'test "$(stat -Lc %d:%i /proc/1/root)" != "$(stat -Lc %d:%i /)"'
        )
        result = run_shellout(instruction, timeout: SHELL_DETECTION_TIMEOUT)
        if result.exit_status.zero?
          probe = run_target_command('echo ready', timeout: SHELL_DETECTION_TIMEOUT)
          return if probe.exit_status.zero? && probe.stdout.strip == 'ready'

          raise EphemeralContainerError,
                "Cannot run commands against #{unique_identifier} from the ephemeral container: #{probe.stderr.strip}"
        end

        raise EphemeralContainerError,
              "Cannot access the target filesystem from #{container_name}; " \
              'the container runtime must support --target process namespace sharing'
      end

      def run_target_command(command, timeout:)
        # Keep the parent shell alive: its /proc/<pid>/root exposes BusyBox
        # binaries after chroot changes the child's root to the target image.
        script = 'debug_root="/proc/$$/root"; ' \
                 'export PATH="$debug_root/bin:$debug_root/usr/bin"; ' \
                 'chroot /proc/1/root "$debug_root/bin/sh" -c ' +
                 Shellwords.escape(command) + '; status=$?; exit "$status"'
        run_shellout(@command_builder.with_raw_shell(script), timeout:)
      end
    end
  end
end
