# frozen_string_literal: true

require 'mixlib/shellout' unless defined?(Mixlib::ShellOut)
require 'train/options'
require 'train/extras'

module TrainPlugins
  module K8sContainer
    # Kubectl exec client for executing commands in Kubernetes containers
    class KubectlExecClient
      attr_reader :pod, :container_name, :namespace

      DEFAULT_NAMESPACE = 'default'

      def initialize(pod:, namespace: nil, container_name: nil, kubectl_path: 'kubectl')
        @pod = pod
        @container_name = container_name
        @namespace = namespace
        @kubectl_path = kubectl_path
      end

      def execute(command)
        instruction = build_instruction(command)
        shell = Mixlib::ShellOut.new(instruction)
        res = shell.run_command
        Train::Extras::CommandResult.new(res.stdout, res.stderr, res.exitstatus)
      rescue Errno::ENOENT => _e
        Train::Extras::CommandResult.new('', '', 1)
      end

      private

      def build_instruction(command)
        [@kubectl_path, 'exec'].tap do |arr|
          arr << '--stdin'
          arr << pod if pod
          if namespace
            arr << '-n'
            arr << namespace
          end
          if container_name
            arr << '-c'
            arr << container_name
          end
          arr << '--'
          arr << sh_run_command(command)
        end.join(' ')
      end

      def sh_run_command(command)
        ['/bin/sh', '-c', command]
      end
    end
  end
end
