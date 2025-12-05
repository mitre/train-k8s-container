# frozen_string_literal: true

require 'shellwords'

module TrainPlugins
  module K8sContainer
    # Builds kubectl exec command strings with proper escaping
    # Consolidates all command building logic to eliminate duplication
    class KubectlCommandBuilder
      attr_reader :kubectl_path, :pod, :namespace, :container_name

      def initialize(kubectl_path:, pod:, namespace:, container_name:)
        @kubectl_path = kubectl_path
        @pod = pod
        @namespace = namespace
        @container_name = container_name
      end

      # Base kubectl exec command components (used by all builders)
      def base_command
        [
          @kubectl_path, 'exec', '--stdin',
          @pod, '-n', @namespace, '-c', @container_name,
        ]
      end

      # Build command for Unix shell execution
      # @param shell_path [String] Path to shell (e.g., '/bin/bash')
      # @param command [String] Command to execute
      # @return [String] Complete kubectl command
      def with_shell(shell_path, command)
        [
          *base_command,
          '--', shell_path, '-c', Shellwords.escape(command),
        ].join(' ')
      end

      # Build command for Windows shell execution
      # @param shell_path [String] Shell name (e.g., 'cmd.exe', 'powershell.exe')
      # @param command [String] Command to execute
      # @return [String] Complete kubectl command
      def with_windows_shell(shell_path, command)
        flag = shell_flag_for(shell_path)
        [
          *base_command,
          '--', shell_path, flag, Shellwords.escape(command),
        ].join(' ')
      end

      # Build command for direct binary execution (no shell)
      # @param command [String] Command to execute (will be split on spaces)
      # @return [String] Complete kubectl command
      def direct_binary(command)
        [
          *base_command,
          '--',
        ].concat(command.split).join(' ')
      end

      # Build command with hardcoded /bin/sh (for raw execution)
      # @param command [String] Command to execute
      # @return [String] Complete kubectl command
      def with_raw_shell(command)
        [
          *base_command,
          '--', '/bin/sh', '-c', Shellwords.escape(command),
        ].join(' ')
      end

      private

      # Get the appropriate shell flag for Windows shells
      # @param shell_path [String] Shell path
      # @return [String] Shell flag ('/c' for cmd, '-Command' for PowerShell)
      def shell_flag_for(shell_path)
        case shell_path
        when 'cmd.exe'
          '/c'
        when 'powershell.exe', 'pwsh.exe'
          '-Command'
        else
          '-c' # Fallback to Unix-style
        end
      end
    end
  end
end
