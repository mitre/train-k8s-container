# frozen_string_literal: true

module TrainPlugins
  module K8sContainer
    # Platform detection module for k8s-container transport
    module Platform
      def platform
        # Detect container OS to set appropriate families
        detect_shell # This triggers OS detection in ShellDetector
        container_os = @shell_detector&.container_os || :unknown

        # Declare base families (always present)
        Train::Platforms.name('k8s-container').in_family('cloud')
        Train::Platforms.name('k8s-container').in_family('container')

        # Declare OS-specific family based on actual detected container OS
        case container_os
        when :unix
          Train::Platforms.name('k8s-container').in_family('unix')
        when :windows
          Train::Platforms.name('k8s-container').in_family('windows')
          # when :unknown, :none - Don't declare OS family if we can't detect it
        end

        force_platform!('k8s-container', release: TrainPlugins::K8sContainer::VERSION)
      end

      private

      def detect_shell
        # Delegate to Connection's shell detection
        # This ensures @shell_detector is initialized
        @shell_detector ||= ShellDetector.new(kubectl_client) if respond_to?(:kubectl_client)
        @shell_detector&.detect
      end
    end
  end
end
