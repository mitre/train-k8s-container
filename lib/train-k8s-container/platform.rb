# frozen_string_literal: true

module TrainPlugins
  module K8sContainer
    # Platform detection module for k8s-container transport
    module Platform
      def platform
        Train::Platforms.name('k8s-container').in_family('cloud')
        Train::Platforms.name('k8s-container').in_family('unix')
        force_platform!('k8s-container', release: TrainPlugins::K8sContainer::VERSION)
      end
    end
  end
end
