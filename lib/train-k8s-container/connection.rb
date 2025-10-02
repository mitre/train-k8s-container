# frozen_string_literal: true

require 'train'
require 'train/plugins'
require 'train/file/remote/linux'
module TrainPlugins
  module K8sContainer
    # Connection class for Kubernetes container transport
    # Executes commands inside containers via kubectl exec
    class Connection < Train::Plugins::Transport::BaseConnection
      include Train::Platforms::Common

      # URI format: k8s-container://<namespace>/<pod>/<container_name>
      # @example k8s-container://default/shell-demo/nginx

      def initialize(options)
        super

        raise 'Unsupported host platform.' if RUBY_PLATFORM =~ /windows|mswin|msys|mingw|cygwin/

        uri_path = options[:path]&.gsub(%r{^/}, '')
        @pod = options[:pod] || uri_path&.split('/')&.first
        @container_name = options[:container_name] || uri_path&.split('/')&.last
        host = !options[:host].nil? && !options[:host].empty? ? options[:host] : nil
        @namespace = options[:namespace] || host || TrainPlugins::K8sContainer::KubectlExecClient::DEFAULT_NAMESPACE
        validate_parameters
      end

      def uri
        "k8s-container://#{@namespace}/#{@pod}/#{@container_name}"
      end

      def unique_identifier
        "#{@namespace}/#{@pod}/#{@container_name}"
      end

      def platform
        @platform ||= Train::Platforms::Detect.scan(self)
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
      end

      def file_via_connection(path, *_args)
        ::Train::File::Remote::Linux.new(self, path)
      end
    end
  end
end
