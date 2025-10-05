# frozen_string_literal: true

require_relative 'shell_detector'

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

        # Declare OS-specific family based on detected container OS
        case container_os
        when :unix
          Train::Platforms.name('k8s-container').in_family('unix')
        when :windows
          Train::Platforms.name('k8s-container').in_family('windows')
        else
          # Unknown - log warning if in production (not test)
          # Don't declare OS family - will cause InSpec resource errors
          warn 'Unable to detect container OS. InSpec resources may not work.' unless ENV['RSPEC_RUNNING']
        end

        force_platform!('k8s-container', release: TrainPlugins::K8sContainer::VERSION)
      end

      private

      def detect_shell
        # When called from Connection, kubectl_client is available (private method)
        # When called from test doubles, it may not be
        return unless is_a?(Train::Plugins::Transport::BaseConnection)

        # Use send to call private kubectl_client method
        client = send(:kubectl_client)
        @shell_detector ||= ShellDetector.new(client)
        @shell_detector.detect
      rescue NoMethodError
        # kubectl_client not available (test environment or incomplete setup)
        nil
      end
    end
  end
end
