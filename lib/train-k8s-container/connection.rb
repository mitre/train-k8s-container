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

        # Parse URI path: /namespace/pod/container or //pod/container (default namespace)
        uri_path = options[:path]&.gsub(%r{^/}, '')
        path_parts = uri_path&.split('/')

        # Extract from path or use explicit options
        host = !options[:host].nil? && !options[:host].empty? ? options[:host] : nil
        @namespace = options[:namespace] || host || path_parts&.first || TrainPlugins::K8sContainer::KubectlExecClient::DEFAULT_NAMESPACE
        @pod = options[:pod] || path_parts&.[](1)
        @container_name = options[:container_name] || path_parts&.[](2)

        validate_parameters
      end

      def uri
        "k8s-container://#{@namespace}/#{@pod}/#{@container_name}"
      end

      def unique_identifier
        "#{@namespace}/#{@pod}/#{@container_name}"
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
