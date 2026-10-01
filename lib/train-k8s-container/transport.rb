# frozen_string_literal: true

require 'train'
require 'train/plugins'

module TrainPlugins
  module K8sContainer
    # Train transport for connecting to Kubernetes containers via kubectl exec
    class Transport < Train.plugin(1)
      require_relative 'connection'

      name 'k8s-container'

      option :kubeconfig, default: ENV['KUBECONFIG'] || '~/.kube/config'
      option :pod, default: nil
      option :container_name, default: nil
      option :namespace, default: nil
      option :use_ephemeral_container, default: ENV['TRAIN_K8S_EPHEMERAL'] == 'true'
      option :ephemeral_image, default: 'busybox:1.36-musl'

      def connection(state = nil, &)
        opts = merge_options(@options, state || {})
        create_new_connection(opts, &)
      end

      def create_new_connection(options, &)
        @connection_options = options
        @connection = Connection.new(options, &)
      end
    end
  end
end
