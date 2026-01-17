# frozen_string_literal: true

# InSpec Resource Validation for train-k8s-container
#
# This profile validates that InSpec resources work correctly when using
# the train-k8s-container transport. It tests PTY output parsing, file
# operations, user/group resources, and various other InSpec capabilities.
#
# Usage:
#   cinc-auditor exec test/fixtures/profiles/inspec-resource-validation \
#     -t k8s-container:///test-ubuntu/test-ubuntu

# =============================================================================
# Core PTY Output Parsing Tests (pty-1 through pty-15)
# These are the scenarios that differ between v1.x and v2.x
# =============================================================================

control 'pty-1' do
  impact 1.0
  title 'Simple command execution'
  desc 'Verify basic command execution works'

  describe command('whoami') do
    its('stdout') { should match(/root/) }
    its('exit_status') { should eq 0 }
  end
end

control 'pty-2' do
  impact 1.0
  title 'Multi-line command execution'
  desc 'Verify multi-line commands work (THE BUG SCENARIO)'

  # This is the exact type of command that triggered the v2.x bug
  describe command('for f in /etc/*.conf; do echo "Found: $f"; done') do
    its('stdout') { should_not match(/^for f in/) } # Should NOT contain command echo
    its('stdout') { should_not include('2>&1') }    # Should NOT contain wrapper
    its('exit_status') { should eq 0 }
  end
end

control 'pty-3' do
  impact 1.0
  title 'Directory existence check'
  desc 'Verify directory existence detection (InSpec directory resource)'

  describe file('/etc') do
    it { should exist }
    it { should be_directory }
  end

  describe file('/var/log') do
    it { should exist }
    it { should be_directory }
  end
end

control 'pty-4' do
  impact 1.0
  title 'File content reading'
  desc 'Verify file content can be read correctly'

  describe file('/etc/os-release') do
    it { should exist }
    its('content') { should match(/Ubuntu/) }
  end
end

control 'pty-5' do
  impact 1.0
  title 'Exit code handling'
  desc 'Verify exit codes are captured correctly'

  describe command('true') do
    its('exit_status') { should eq 0 }
  end

  describe command('false') do
    its('exit_status') { should eq 1 }
  end
end

control 'pty-6' do
  impact 1.0
  title 'Command with special characters'
  desc 'Verify commands with special shell characters work'

  describe command("echo 'test $VAR' | cat") do
    its('stdout') { should match(/test/) }
    its('exit_status') { should eq 0 }
  end
end

control 'pty-7' do
  impact 1.0
  title 'Stat command output'
  desc 'Verify stat command output parsing (used by InSpec file resource)'

  describe command('stat /etc') do
    its('stdout') { should match(%r{File:.*/etc}) }
    its('stdout') { should_not include('2>&1') }
    its('exit_status') { should eq 0 }
  end
end

control 'pty-8' do
  impact 1.0
  title 'User resource'
  desc 'Verify user resource works'

  describe user('root') do
    it { should exist }
    its('uid') { should eq 0 }
  end
end

control 'pty-9' do
  impact 1.0
  title 'Group resource'
  desc 'Verify group resource works'

  describe group('root') do
    it { should exist }
    its('gid') { should eq 0 }
  end
end

control 'pty-10' do
  impact 1.0
  title 'Package resource'
  desc 'Verify package resource works'

  describe package('coreutils') do
    it { should be_installed }
  end
end

control 'pty-11' do
  impact 1.0
  title 'Process resource'
  desc 'Verify process listing works'

  # The sleep infinity process should be running (keeps container alive)
  describe processes('sleep') do
    it { should exist }
  end
end

control 'pty-12' do
  impact 1.0
  title 'File content parsing'
  desc 'Verify file content with multiple lines parses correctly'

  describe file('/etc/passwd') do
    it { should exist }
    its('content') { should match(/root:/) }
    its('size') { should be_positive }
    its('mode') { should cmp '0644' }
  end
end

control 'pty-13' do
  impact 1.0
  title 'Symlink handling'
  desc 'Verify symlink detection works'

  # /bin is a symlink to /usr/bin on modern Ubuntu (20.04+)
  # This replaces the broken /etc/mtab test
  describe file('/bin') do
    it { should exist }
    it { should be_symlink }
    it { should be_linked_to '/usr/bin' }
  end
end

control 'pty-14' do
  impact 1.0
  title 'Command with pipe'
  desc 'Verify piped commands work'

  describe command('cat /etc/passwd | wc -l') do
    its('stdout') { should match(/\d+/) }
    its('exit_status') { should eq 0 }
  end
end

control 'pty-15' do
  impact 1.0
  title 'Command with quotes and variables'
  desc 'Verify complex shell parsing'

  describe command('echo "HOME=$HOME" | grep HOME') do
    its('stdout') { should match(/HOME=/) }
    its('exit_status') { should eq 0 }
  end
end

# =============================================================================
# Extended Resource Coverage (pty-16 through pty-35)
# Additional InSpec resources to ensure comprehensive validation
# =============================================================================

control 'pty-16' do
  impact 1.0
  title 'Mount resource'
  desc 'Verify mount information can be retrieved'

  describe mount('/') do
    it { should be_mounted }
  end
end

control 'pty-17' do
  impact 1.0
  title 'Environment variable resource'
  desc 'Verify environment variables can be read'

  describe os_env('PATH') do
    its('content') { should include('/usr/bin') }
  end
end

control 'pty-18' do
  impact 1.0
  title 'Kernel parameter resource'
  desc 'Verify kernel parameters can be read'

  describe kernel_parameter('kernel.pid_max') do
    its('value') { should be_positive }
  end
end

control 'pty-19' do
  impact 1.0
  title 'Interface resource'
  desc 'Verify network interface information'

  # lo (loopback) should always exist
  describe interface('lo') do
    it { should exist }
  end
end

control 'pty-20' do
  impact 1.0
  title 'File owner and group'
  desc 'Verify file ownership attributes are parsed correctly'

  describe file('/etc/passwd') do
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('type') { should eq :file }
  end
end

control 'pty-21' do
  impact 1.0
  title 'Directory with symlinks'
  desc 'Verify directories containing symlinks work'

  # /etc/alternatives contains symlinks on Debian-based systems
  describe file('/etc/alternatives') do
    it { should exist }
    it { should be_directory }
  end
end

control 'pty-22' do
  impact 1.0
  title 'etc_passwd entries'
  desc 'Verify /etc/passwd parsing via passwd resource'

  describe passwd do
    its('users') { should include 'root' }
    its('uids') { should include '0' } # UIDs are strings in passwd resource
  end

  describe passwd.users('root') do
    its('uids') { should eq ['0'] }
    its('gids') { should eq ['0'] }
  end
end

control 'pty-23' do
  impact 1.0
  title 'etc_group entries'
  desc 'Verify /etc/group parsing via group resource'

  describe etc_group do
    its('groups') { should include 'root' }
    its('gids') { should include 0 }
  end
end

control 'pty-24' do
  impact 1.0
  title 'Large output handling'
  desc 'Verify commands with large output are handled correctly'

  # Generate substantial output
  describe command('find /etc -type f 2>/dev/null | head -50') do
    its('stdout') { should match(%r{/etc/}) }
    its('exit_status') { should eq 0 }
  end
end

control 'pty-25' do
  impact 1.0
  title 'Command with stderr'
  desc 'Verify commands that produce stderr are handled'

  # ls on non-existent file produces stderr
  describe command('ls /nonexistent_file_12345 2>&1') do
    its('stdout') { should match(/No such file|cannot access/) }
    its('exit_status') { should_not eq 0 }
  end
end

control 'pty-26' do
  impact 1.0
  title 'Empty output handling'
  desc 'Verify commands with no output work correctly'

  describe command('true') do
    its('stdout') { should eq '' }
    its('exit_status') { should eq 0 }
  end
end

control 'pty-27' do
  impact 1.0
  title 'Nested directory structure'
  desc 'Verify deep directory traversal works'

  describe file('/usr/share/doc') do
    it { should exist }
    it { should be_directory }
  end
end

control 'pty-28' do
  impact 1.0
  title 'Login defs parsing'
  desc 'Verify login.defs can be parsed'

  only_if('login.defs exists') do
    file('/etc/login.defs').exist?
  end

  describe login_defs do
    its('PASS_MAX_DAYS') { should_not be_nil }
  end
end

control 'pty-29' do
  impact 1.0
  title 'OS detection'
  desc 'Verify platform detection works correctly'

  describe os.family do
    it { should eq 'debian' }
  end

  describe os.name do
    it { should eq 'ubuntu' }
  end

  describe os.release do
    it { should match(/22\.04/) }
  end
end

control 'pty-30' do
  impact 1.0
  title 'Command with embedded newlines'
  desc 'Verify commands containing newlines in output work'

  describe command("printf 'line1\\nline2\\nline3'") do
    its('stdout') { should match(/line1/) }
    its('stdout') { should match(/line2/) }
    its('stdout') { should match(/line3/) }
    its('exit_status') { should eq 0 }
  end
end

control 'pty-31' do
  impact 1.0
  title 'File with specific permissions'
  desc 'Verify numeric permission modes are parsed'

  describe file('/etc/shadow') do
    it { should exist }
    # Shadow file should be restricted
    it { should_not be_readable.by('others') }
  end
end

control 'pty-32' do
  impact 1.0
  title 'Command timeout handling'
  desc 'Verify quick commands complete without timeout'

  describe command('echo quick') do
    its('stdout') { should match(/quick/) }
    its('exit_status') { should eq 0 }
  end
end

control 'pty-33' do
  impact 1.0
  title 'JSON output parsing'
  desc 'Verify JSON output from commands is preserved'

  describe command('echo \'{"key": "value"}\'') do
    its('stdout') { should match(/\{"key": "value"\}/) }
  end
end

control 'pty-34' do
  impact 1.0
  title 'Bash array and subshell'
  desc 'Verify complex bash constructs work'

  describe command('echo $(echo nested)') do
    its('stdout') { should match(/nested/) }
    its('exit_status') { should eq 0 }
  end
end
