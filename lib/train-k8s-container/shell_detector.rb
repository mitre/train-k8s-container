# frozen_string_literal: true

module TrainPlugins
  module K8sContainer
    # Detects available shell in container with tiered fallback
    # Supports bash, sh, ash, and distroless (no shell) containers
    class ShellDetector
      SHELL_PRIORITY = [
        '/bin/bash',   # Ubuntu, Debian, RHEL, CentOS
        '/bin/sh',     # POSIX standard, symlink in most distros
        '/bin/ash',    # Alpine, BusyBox
        '/bin/zsh',    # Less common but possible
      ].freeze

      def initialize(kubectl_client)
        @kubectl_client = kubectl_client
        @detected_shell = :not_detected
      end

      def detect
        return @detected_shell unless @detected_shell == :not_detected

        SHELL_PRIORITY.each do |shell_path|
          if shell_available?(shell_path)
            @detected_shell = shell_path
            return @detected_shell
          end
        end

        @detected_shell = nil # No shell available (distroless)
      end

      def shell_available?(shell_path)
        # Use test -x to check if shell exists and is executable
        result = @kubectl_client.execute_raw("test -x #{shell_path} && echo OK")
        result.stdout.strip == 'OK' && result.exit_status == 0
      rescue StandardError
        false
      end

      def shell_type
        case @detected_shell
        when '/bin/bash' then :bash
        when '/bin/sh' then :sh
        when '/bin/ash' then :ash
        when '/bin/zsh' then :zsh
        when nil then :none
        else :unknown
        end
      end
    end
  end
end
