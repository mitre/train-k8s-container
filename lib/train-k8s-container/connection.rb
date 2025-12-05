# frozen_string_literal: true

require 'train'
require 'train/plugins'
require 'train/file/remote/linux'
require 'train/file/remote/windows'
require_relative 'platform'
require_relative 'kubernetes_name_validator'

module TrainPlugins
  module K8sContainer
    # Connection class for Kubernetes container transport
    # Executes commands inside containers via kubectl exec
    class Connection < Train::Plugins::Transport::BaseConnection
      include TrainPlugins::K8sContainer::Platform

      # URI format: k8s-container://<namespace>/<pod>/<container_name>
      # @example k8s-container://default/shell-demo/nginx

      def initialize(options)
        super

        # Parse URI path format (InSpec converts k8s-container://target to path="//target"):
        # - k8s-container://pod/container → path="//pod/container" (default namespace)
        # - k8s-container://namespace/pod/container → path="//namespace/pod/container"
        path_parts = options[:path]&.split('/')&.reject(&:empty?)

        if path_parts&.length == 2
          # Format: //pod/container (default namespace)
          @namespace = options[:namespace] || TrainPlugins::K8sContainer::KubectlExecClient::DEFAULT_NAMESPACE
          @pod = options[:pod] || path_parts.first
          @container_name = options[:container_name] || path_parts[1]
        elsif path_parts&.length == 3
          # Format: //namespace/pod/container
          @namespace = options[:namespace] || path_parts.first
          @pod = options[:pod] || path_parts[1]
          @container_name = options[:container_name] || path_parts[2]
        else
          # No valid path - must use explicit options
          @namespace = options[:namespace] || TrainPlugins::K8sContainer::KubectlExecClient::DEFAULT_NAMESPACE
          @pod = options[:pod]
          @container_name = options[:container_name]
        end

        validate_parameters
      end

      def uri
        "k8s-container://#{@namespace}/#{@pod}/#{@container_name}"
      end

      # Delegate to kubectl_client for consistent identifier across all components
      def unique_identifier
        kubectl_client.unique_identifier
      end

      private

      attr_reader :pod, :container_name, :namespace

      def kubectl_client
        @kubectl_client ||= KubectlExecClient.new(
          pod:,
          namespace:,
          container_name:
        )
      end

      def run_command_via_connection(cmd, &)
        kubectl_client.execute(cmd)
      end

      def validate_parameters
        raise ArgumentError, 'Missing Parameter `pod`' unless pod
        raise ArgumentError, 'Missing Parameter `container_name`' unless container_name

        # Validate Kubernetes resource names (RFC 1123 compliance, injection prevention)
        KubernetesNameValidator.validate!(pod, resource_type: 'pod')
        KubernetesNameValidator.validate!(namespace, resource_type: 'namespace')
        KubernetesNameValidator.validate!(container_name, resource_type: 'container')
      end

      def file_via_connection(path, *_args)
        # Basic path traversal prevention
        raise ArgumentError, 'File path cannot be nil' if path.nil?
        raise ArgumentError, 'File path cannot be empty' if path.empty?

        # Detect container OS to use appropriate file handler
        detect_shell # Triggers OS detection in ShellDetector
        container_os = @shell_detector&.container_os || :unknown

        case container_os
        when :windows
          ::Train::File::Remote::Windows.new(self, path)
        else
          # Default to Linux for unix and unknown (distroless still uses Unix paths)
          ::Train::File::Remote::Linux.new(self, path)
        end
      end
    end
  end
end
