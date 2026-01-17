# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container'

RSpec.describe 'PTY Output Parsing' do
  # This test suite specifically targets the parse_output method in PtySession
  # to verify it correctly handles various output scenarios

  # Fixed marker ID for testing (in production, this is SecureRandom.hex(4))
  let(:test_marker_id) { 'deadbeef' }
  let(:exit_marker) { "__EXIT_CODE_#{test_marker_id}__" }
  let(:wrapper_suffix) { "; echo #{exit_marker}=$?" }

  let(:session) do
    # Create a minimal session object for testing parse_output
    TrainPlugins::K8sContainer::PtySession.allocate.tap do |s|
      s.instance_variable_set(:@session_key, 'test/pod/container')
      s.instance_variable_set(:@logger, nil)
      s.instance_variable_set(:@marker_id, test_marker_id)
    end
  end

  describe '#parse_output' do
    # Helper to call private parse_output method
    def parse_output(buffer, command)
      session.send(:parse_output, buffer, command)
    end

    context 'simple command without echo-back' do
      it 'extracts stdout correctly' do
        buffer = "root\n#{exit_marker}=0\n"
        result = parse_output(buffer, 'whoami')

        expect(result.stdout).to eq('root')
        expect(result.stderr).to eq('')
        expect(result.exit_status).to eq(0)
      end

      it 'returns output in stdout even for failed commands (PTY merges streams)' do
        buffer = "bash: nonexistent: command not found\n#{exit_marker}=127\n"
        result = parse_output(buffer, 'nonexistent')

        # PTY merges stdout/stderr - all output goes to stdout
        # Caller uses exit_status to determine success/failure
        expect(result.stdout).to eq('bash: nonexistent: command not found')
        expect(result.stderr).to eq('')
        expect(result.exit_status).to eq(127)
      end
    end

    context 'command with echo-back (common in PTY)' do
      it 'filters out echoed command' do
        # Shell typically echoes the command before output
        buffer = "whoami\nroot\n#{exit_marker}=0\n"
        result = parse_output(buffer, 'whoami')

        expect(result.stdout).to eq('root')
        expect(result.exit_status).to eq(0)
      end

      it 'filters out command with wrapper' do
        # Our wrapper adds the unique marker suffix
        buffer = "echo test #{wrapper_suffix}\ntest\n#{exit_marker}=0\n"
        result = parse_output(buffer, 'echo test')

        expect(result.stdout).to eq('test')
        expect(result.stdout).not_to include('2>&1')
        expect(result.stdout).not_to include(exit_marker)
      end
    end

    context 'multi-line command (THE BUG SCENARIO)' do
      it 'filters out multi-line command echo-back' do
        # This is the exact scenario that fails in production
        command = <<~SHELL.strip
          for f in /etc/*.conf; do
            echo "Found: $f"
          done
        SHELL

        # Shell echoes back the multi-line command with our wrapper
        buffer = <<~OUTPUT
          for f in /etc/*.conf; do
            echo "Found: $f"
          done
           #{wrapper_suffix}
          Found: /etc/adduser.conf
          Found: /etc/debconf.conf
          #{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, command)

        # Output should NOT contain the command
        expect(result.stdout).not_to include('for f in'),
                                     "Output still contains command: #{result.stdout.inspect}"
        expect(result.stdout).not_to include('2>&1'),
                                     "Output still contains wrapper: #{result.stdout.inspect}"

        # Output SHOULD contain actual results
        expect(result.stdout).to include('Found: /etc/adduser.conf')
        expect(result.exit_status).to eq(0)
      end

      it 'handles the certificate check command from bug report' do
        command = <<~SHELL.strip
          for f in $(find -L /etc/ssl/certs -type f); do
            openssl x509 -sha256 -in $f -noout -fingerprint | cut -d= -f2 | tr -d ':' | egrep -vw 'PATTERN'
          done
        SHELL

        buffer = <<~OUTPUT
          for f in $(find -L /etc/ssl/certs -type f); do
            openssl x509 -sha256 -in $f -noout -fingerprint | cut -d= -f2 | tr -d ':' | egrep -vw 'PATTERN'
          done
           #{wrapper_suffix}
          find: '/etc/ssl/certs': No such file or directory
          #{exit_marker}=1
        OUTPUT

        result = parse_output(buffer, command)

        # Output should NOT contain the command
        expect(result.stdout).not_to include('for f in'),
                                     "Output contains command: #{result.stdout.inspect}"

        # Output SHOULD contain the actual error (in stdout - PTY merges streams)
        expect(result.stdout).to include('No such file or directory'),
                                 "Error not in stdout: #{result.stdout.inspect}"
        expect(result.exit_status).to eq(1)
      end
    end

    context 'stat command (used by InSpec directory resource)' do
      it 'parses stat output for existing directory' do
        command = 'stat /etc'
        buffer = <<~OUTPUT
          stat /etc #{wrapper_suffix}
            File: /etc
            Size: 4096       Blocks: 8          IO Block: 4096   directory
          Access: (0755/drwxr-xr-x)  Uid: (    0/    root)   Gid: (    0/    root)
          #{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, command)

        expect(result.stdout).to include('File: /etc')
        expect(result.stdout).to include('directory')
        expect(result.stdout).not_to include('2>&1')
        expect(result.exit_status).to eq(0)
      end

      it 'parses stat output for non-existing directory' do
        command = 'stat /var/log'
        buffer = <<~OUTPUT
          stat /var/log #{wrapper_suffix}
          stat: cannot stat '/var/log': No such file or directory
          #{exit_marker}=1
        OUTPUT

        result = parse_output(buffer, command)

        # PTY merges stdout/stderr - error message is in stdout
        expect(result.stdout).to include('No such file or directory'),
                                 "Expected error in stdout: #{result.inspect}"
        expect(result.exit_status).to eq(1)
      end
    end

    context 'ANSI escape sequences' do
      it 'strips ANSI color codes' do
        buffer = "\e[32mgreen text\e[0m\n#{exit_marker}=0\n"
        result = parse_output(buffer, 'echo')

        expect(result.stdout).not_to include("\e[")
        expect(result.stdout).to include('green text')
      end
    end

    context 'edge cases' do
      it 'handles empty command output' do
        buffer = "echo #{wrapper_suffix}\n#{exit_marker}=0\n"
        result = parse_output(buffer, 'echo')

        expect(result.stdout).to eq('')
        expect(result.exit_status).to eq(0)
      end

      it 'handles output with special characters' do
        # Test that output with shell-like characters is preserved
        buffer = <<~OUTPUT
          cat script.sh #{wrapper_suffix}
          #!/bin/bash
          echo "test $VAR"
          exit 0
          #{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, 'cat script.sh')

        expect(result.stdout).to include('#!/bin/bash')
        expect(result.stdout).to include('echo "test $VAR"')
        expect(result.exit_status).to eq(0)
      end

      it 'preserves user output containing generic EXIT_CODE text' do
        # User output might contain EXIT_CODE text, but NOT our unique marker
        # Our UUID-based marker (e.g., __EXIT_CODE_deadbeef__) is unique per session
        buffer = <<~OUTPUT
          echo test #{wrapper_suffix}
          My variable is __EXIT_CODE__=42
          Some other EXIT_CODE reference
          #{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, 'echo test')

        # Should preserve user's text since it doesn't match our unique marker
        expect(result.stdout).to include('My variable is __EXIT_CODE__=42')
        expect(result.stdout).to include('Some other EXIT_CODE reference')
        # Should use OUR marker for exit code
        expect(result.exit_status).to eq(0)
      end

      it 'handles output without trailing newline after wrapper via remove_command_echo' do
        # Edge case: wrapper marker exists but no newline follows
        # Test remove_command_echo directly to verify the edge case branch
        text = "echo test #{wrapper_suffix}output_no_newline"
        command = 'echo test'

        # Call the private method directly
        result = session.send(:remove_command_echo, text, command)

        # Should capture content after wrapper even without newline
        expect(result).to eq('output_no_newline')
      end

      it 'handles --printf format where marker is appended to last line' do
        # Train's stat command uses --printf which doesn't add trailing newline
        # So our marker gets appended: "?\n__EXIT_CODE_xxx__=0" not "?\n__EXIT_CODE_xxx__=0\n"
        # This is the stat output format: 9 fields, last one is selinux context "?"
        command = "stat /etc --printf '%s\\n%f\\n%U\\n%u\\n%G\\n%g\\n%X\\n%Y\\n%C'"
        buffer = <<~OUTPUT.chomp
          #{command} #{wrapper_suffix}
          4096
          41ed
          root
          0
          root
          0
          1609459200
          1609459200
          ?#{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, command)

        # Should have exactly 9 lines (fields) for stat parsing
        lines = result.stdout.split("\n")
        expect(lines.length).to eq(9), "Expected 9 fields, got #{lines.length}: #{lines.inspect}"
        expect(lines.last).to eq('?'), "Last field should be '?' (selinux), got: #{lines.last.inspect}"
        expect(result.exit_status).to eq(0)
      end

      it 'handles shell expanding $? in echo-back (THE CI BUG SCENARIO)' do
        # Some shells expand $? BEFORE echoing the command back
        # So instead of: "command 2>&1 ; echo __EXIT_CODE_xxx__=$?"
        # We see:        "command 2>&1 ; echo __EXIT_CODE_xxx__=0"
        # Our pattern matching must handle this!
        #
        # Note: Use \\\\n for literal backslash-n in the printf format
        # (as it appears in real PTY echo-back)
        command = "stat /etc --printf '%s\\\\n%f\\\\n%U\\\\n%u\\\\n%G\\\\n%g\\\\n%X\\\\n%Y\\\\n%C'"

        # Simulate shell expanding $? to 0 in the echo-back
        # Note: echo-back shows "=0" not "=$?"
        expanded_wrapper = "2>&1 ; echo #{exit_marker}=0"
        buffer = <<~OUTPUT.chomp
          #{command} #{expanded_wrapper}
          4096
          41ed
          root
          0
          root
          0
          1609459200
          1609459200
          ?#{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, command)

        # Should still have exactly 9 lines (fields) for stat parsing
        lines = result.stdout.split("\n")
        expect(lines.length).to eq(9), "Expected 9 fields, got #{lines.length}: #{lines.inspect}"
        expect(lines.first).to eq('4096'), "First field (size) should be '4096', got: #{lines.first.inspect}"
        expect(lines[1]).to eq('41ed'), "Second field (mode hex) should be '41ed', got: #{lines[1].inspect}"
        expect(lines.last).to eq('?'), "Last field should be '?' (selinux), got: #{lines.last.inspect}"
        expect(result.exit_status).to eq(0)
      end

      it 'handles shell expanding $? to non-zero in echo-back' do
        # Edge case: previous command had non-zero exit, shell shows that in echo-back
        # But actual command succeeds with exit 0
        command = 'whoami'

        # Shell echoes with previous exit code (e.g., 127)
        expanded_wrapper = "2>&1 ; echo #{exit_marker}=127"
        buffer = <<~OUTPUT
          #{command} #{expanded_wrapper}
          root
          #{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, command)

        expect(result.stdout).to eq('root')
        expect(result.exit_status).to eq(0) # Actual exit code, not the echoed one
      end
    end
  end

  describe 'marker uniqueness' do
    it 'generates unique marker per session' do
      session1 = TrainPlugins::K8sContainer::PtySession.allocate.tap do |s|
        s.instance_variable_set(:@marker_id, SecureRandom.hex(4))
      end
      session2 = TrainPlugins::K8sContainer::PtySession.allocate.tap do |s|
        s.instance_variable_set(:@marker_id, SecureRandom.hex(4))
      end

      marker1 = session1.instance_variable_get(:@marker_id)
      marker2 = session2.instance_variable_get(:@marker_id)

      expect(marker1).not_to eq(marker2)
    end

    it 'marker format prevents collision with common output patterns' do
      # The marker format __EXIT_CODE_<hex>__ is highly unlikely in user output
      expect(exit_marker).to match(/^__EXIT_CODE_[0-9a-f]{8}__$/)
    end
  end
end
