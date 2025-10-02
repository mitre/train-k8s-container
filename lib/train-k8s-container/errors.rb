# frozen_string_literal: true

require 'train'

module TrainPlugins
  module K8sContainer
    # Base error class for k8s-container transport
    class K8sContainerError < Train::TransportError; end

    # kubectl binary not found in PATH
    class KubectlNotFoundError < K8sContainerError; end

    # Container not found in specified pod
    class ContainerNotFoundError < K8sContainerError; end

    # Pod not found in specified namespace
    class PodNotFoundError < K8sContainerError; end

    # Container has no shell (distroless) and command requires one
    class ShellNotAvailableError < K8sContainerError; end
  end
end
