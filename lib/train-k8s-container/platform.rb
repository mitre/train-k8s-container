# frozen_string_literal: true

require_relative 'shell_detector'

module TrainPlugins
  module K8sContainer
    # Platform detection module for k8s-container transport
    # Uses Train's built-in platform detection to identify the actual OS
    # inside the container (e.g., ubuntu, alpine, centos) rather than
    # returning a generic 'k8s-container' platform.
    #
    # Additionally adds 'kubernetes' and 'container' to the family hierarchy
    # so users can check platform.kubernetes? and platform.container? to know
    # they are running inside a Kubernetes container.
    module Platform
      # Detect platform inside the container using Train's standard detection
      # This allows InSpec resources to work properly by knowing the actual OS
      def platform
        return @platform if @platform

        # Use Train's built-in platform detection scanner
        # This reads /etc/os-release, /etc/redhat-release, etc. to detect the OS
        @platform = Train::Platforms::Detect.scan(self)

        # If detection fails, fall back to a generic unix platform
        # This handles distroless containers where OS detection may fail
        @platform ||= fallback_platform

        # Add kubernetes and container families so users can check:
        # - platform.kubernetes? => true
        # - platform.container? => true
        add_k8s_families(@platform)

        @platform
      end

      private

      # Register kubernetes and container families with Train and add them
      # to the detected platform's family hierarchy
      def add_k8s_families(plat)
        return unless plat

        # Register the families with Train if not already registered
        # These are added as top-level families (no parent)
        Train::Platforms.family('kubernetes') unless Train::Platforms.families['kubernetes']
        Train::Platforms.family('container') unless Train::Platforms.families['container']

        # Append to the family hierarchy so kubernetes? and container? methods work
        plat.family_hierarchy << 'kubernetes' unless plat.family_hierarchy.include?('kubernetes')
        plat.family_hierarchy << 'container' unless plat.family_hierarchy.include?('container')

        # Re-add platform methods to include the new family? methods
        plat.add_platform_methods
      end

      # Fallback platform when Train's detection fails (distroless, minimal containers)
      def fallback_platform
        detect_shell # Trigger shell detection
        container_os = @shell_detector&.container_os || :unknown

        # Create a minimal platform with appropriate families
        plat = Train::Platforms.name('unknown')

        case container_os
        when :unix
          plat.in_family('unix')
          plat.in_family('linux')
        when :windows
          plat.in_family('windows')
        end

        force_platform!('unknown', release: 'unknown')
      end

      def detect_shell
        return unless is_a?(Train::Plugins::Transport::BaseConnection)

        client = send(:kubectl_client)
        @shell_detector ||= ShellDetector.new(client)
        @shell_detector.detect
      rescue NoMethodError
        nil
      end
    end
  end
end
