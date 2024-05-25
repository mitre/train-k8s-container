require "mixlib/shellout" unless defined?(Mixlib::ShellOut)
require "train/options" # only to load the following requirement `train/extras`
require "train/extras"
require "open3"
require "pty"
require "expect"

module Train
  module K8s
    module Container
      class KubectlExecClient
        attr_reader :pod, :container_name, :namespace

        DEFAULT_NAMESPACE = "default".freeze
        @@session = nil

        def initialize(pod:, namespace: nil, container_name: nil)
          @pod = pod
          @container_name = container_name
          @namespace = namespace
        end

        def disconnect
          @writer.puts "exit" if @writer
          [@reader, @writer].each do |io|
            io.close if io && !io.closed?
          end
          @@session = {}
        rescue IOError
          Train::Extras::CommandResult.new("", "", 1)
        end

        def strip_ansi_sequences(text)
          text.gsub(/\e\[.*?m/, "").gsub(/\e\]0;.*?\a/, "").gsub(/\e\[A/, "").gsub(/\e\[C/, "").gsub(/\e\[K/, "")
        end

        def stream(command)
          instruction = [].tap do |com|
            com << sh_run_command(command)
            com << sh_run_command("echo KUBECTL_EXEC_STATUS:$?")
            com << sh_run_command("echo KUBECTL_EXEC_DONE")
          end.join(";\s")
          session.puts(instruction)
          output = ""
          exit_status = nil
          while (line = session.gets)
            if line.start_with?("KUBECTL_EXEC_STATUS:")
              exit_status = line.chomp.split(":")[1].to_i
            elsif line.chomp == "KUBECTL_EXEC_DONE"
              break
            else
              output += line
            end
          end
          if exit_status.nil?
            puts "Error: Failed to retrieve exit status."
          else
            stdout, stderr = if exit_status == 0
                               [output, ""]
                             else
                               ["", output]
                             end
          end
          Train::Extras::CommandResult.new(stdout, stderr, exit_status)
        end

        def start_session
          @@session = IO.popen(exec_command, "r+")
          # TODO: check if kubectl connection is established
          raise "Failed to open connection" unless @@session
        end

        def execute(command)
          send_command(command)
        rescue => e
          reconnect
          Train::Extras::CommandResult.new("", e.message, 1)
        end

        def close
          disconnect
        end
      end
    end
  end
end

