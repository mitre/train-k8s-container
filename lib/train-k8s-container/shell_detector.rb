# frozen_string_literal: true

module TrainPlugins
  module K8sContainer
    # Detects available shell in container with tiered fallback
    # Supports Unix shells (bash, sh, ash) and Windows shells (cmd, PowerShell)
    class ShellDetector
      UNIX_SHELLS = [
        '/bin/bash',   # Ubuntu, Debian, RHEL, CentOS
        '/bin/sh',     # POSIX standard, symlink in most distros
        '/bin/ash',    # Alpine, BusyBox
        '/bin/zsh', # Less common but possible
      ].freeze

      WINDOWS_SHELLS = [
        'cmd.exe',           # Windows command prompt (most reliable)
        'powershell.exe',    # PowerShell 5.1 (Windows Server)
        'pwsh.exe', # PowerShell Core 6+
      ].freeze

      # Linux distribution family mappings based on /etc/os-release ID
      # Maps distribution IDs to Train family names
      LINUX_FAMILY_MAP = {
        # Debian family
        'debian' => 'debian',
        'ubuntu' => 'debian',
        'linuxmint' => 'debian',
        'raspbian' => 'debian',
        'kali' => 'debian',
        # RedHat family
        'rhel' => 'redhat',
        'centos' => 'redhat',
        'fedora' => 'fedora',
        'rocky' => 'redhat',
        'almalinux' => 'redhat',
        'ol' => 'redhat', # Oracle Linux
        'amzn' => 'redhat', # Amazon Linux
        # SUSE family
        'sles' => 'suse',
        'opensuse' => 'suse',
        'opensuse-leap' => 'suse',
        'opensuse-tumbleweed' => 'suse',
        # Alpine
        'alpine' => 'alpine',
        # Arch
        'arch' => 'arch',
        'manjaro' => 'arch',
        # Gentoo
        'gentoo' => 'gentoo',
      }.freeze

      def initialize(kubectl_client)
        @kubectl_client = kubectl_client
        @detected_shell = :not_detected
        @container_os = :unknown
        @linux_family = nil
      end

      def detect
        return @detected_shell unless @detected_shell == :not_detected

        # Detect container OS first (heuristic approach like train-docker)
        detect_container_os

        # Try appropriate shells based on OS
        shells_to_try = case @container_os
                        when :unix then UNIX_SHELLS
                        when :windows then WINDOWS_SHELLS
                        else UNIX_SHELLS + WINDOWS_SHELLS # Try both if unknown
                        end

        shells_to_try.each do |shell_path|
          if shell_available?(shell_path)
            @detected_shell = shell_path
            return @detected_shell
          end
        end

        @detected_shell = nil # No shell available (distroless)
      end

      def shell_available?(shell_path)
        if self.class.windows_shell?(shell_path)
          windows_shell_available?(shell_path)
        else
          unix_shell_available?(shell_path)
        end
      rescue StandardError
        false
      end

      # Check if shell is a Windows shell (ends with .exe)
      # @param shell_path [String] Path or name of shell
      # @return [Boolean] True if Windows shell
      def self.windows_shell?(shell_path)
        shell_path.end_with?('.exe')
      end

      def unix_shell_available?(shell_path)
        # Use test -x to check if shell exists and is executable
        result = @kubectl_client.execute_raw("test -x #{shell_path} && echo OK")
        result.stdout.strip == 'OK' && result.exit_status.zero?
      end

      def windows_shell_available?(shell_path)
        # For Windows, use 'where' command to check if shell exists
        result = @kubectl_client.execute_raw("where #{shell_path}")
        result.exit_status.zero? && !result.stdout.empty?
      end

      def shell_type
        case @detected_shell
        when '/bin/bash' then :bash
        when '/bin/sh' then :sh
        when '/bin/ash' then :ash
        when '/bin/zsh' then :zsh
        when 'cmd.exe' then :cmd
        when 'powershell.exe' then :powershell
        when 'pwsh.exe' then :pwsh
        when nil then :none
        else :unknown
        end
      end

      attr_reader :container_os, :linux_family

      def windows_container?
        @container_os == :windows
      end

      def unix_container?
        @container_os == :unix
      end

      # Check if container is running Linux (subset of Unix)
      def linux_container?
        @container_os == :unix && !@linux_family.nil?
      end

      private

      def detect_container_os
        # Try a simple Unix command - fails on Windows with specific error pattern
        # Following train-docker's heuristic approach
        result = @kubectl_client.execute_raw('echo test')

        @container_os = if result.exit_status.zero? && result.stdout.strip == 'test'
                          # Unix container (echo works normally)
                          # Also detect Linux family for more specific platform matching
                          detect_linux_family
                          :unix
                        elsif result.stderr.match?(/not recognized|not found|command not found/i)
                          # Likely Windows (Unix commands fail)
                          :windows
                        else
                          # Unknown - will try both shell types
                          :unknown
                        end
      rescue StandardError
        @container_os = :unknown
      end

      # Detect Linux distribution family from /etc/os-release
      # This enables InSpec resources that require os.linux? to work
      def detect_linux_family
        # Try to read /etc/os-release which is standard on modern Linux
        result = @kubectl_client.execute_raw('cat /etc/os-release 2>/dev/null')
        return unless result.exit_status.zero?

        # Parse the ID field from os-release
        os_release = result.stdout
        id_match = os_release.match(/^ID=["']?([^"'\n]+)["']?$/i)
        return unless id_match

        distro_id = id_match[1].downcase.strip
        @linux_family = LINUX_FAMILY_MAP[distro_id]

        # If no exact match, try ID_LIKE for derivative distros
        return if @linux_family

        id_like_match = os_release.match(/^ID_LIKE=["']?([^"'\n]+)["']?$/i)
        return unless id_like_match

        # ID_LIKE can have multiple values, try each one
        id_like_match[1].split.each do |like_id|
          family = LINUX_FAMILY_MAP[like_id.downcase.strip]
          if family
            @linux_family = family
            break
          end
        end
      rescue StandardError
        # Ignore errors - linux_family will remain nil (defaults to generic linux)
        nil
      end
    end
  end
end
