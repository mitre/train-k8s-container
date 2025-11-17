# frozen_string_literal: true

# Test helpers for mocking shell detection scenarios
# Provides consistent mocking patterns across multiple spec files
module ShellDetectionHelpers
  # Mock a Unix container with bash shell available
  # @param client [Object] The kubectl client to mock
  def mock_unix_container_with_bash(client)
    allow(client).to receive(:execute_raw)
      .with('echo test')
      .and_return(double(stdout: 'test', stderr: '', exit_status: 0))
    allow(client).to receive(:execute_raw)
      .with('test -x /bin/bash && echo OK')
      .and_return(double(stdout: 'OK', stderr: '', exit_status: 0))
  end

  # Mock a Unix container with only sh shell (Alpine-style)
  # @param client [Object] The kubectl client to mock
  def mock_unix_container_with_sh(client)
    allow(client).to receive(:execute_raw)
      .with('echo test')
      .and_return(double(stdout: 'test', stderr: '', exit_status: 0))
    allow(client).to receive(:execute_raw)
      .with('test -x /bin/bash && echo OK')
      .and_return(double(stdout: '', stderr: '', exit_status: 1))
    allow(client).to receive(:execute_raw)
      .with('test -x /bin/sh && echo OK')
      .and_return(double(stdout: 'OK', stderr: '', exit_status: 0))
  end

  # Mock a Unix container with only ash shell (BusyBox-style)
  # @param client [Object] The kubectl client to mock
  def mock_unix_container_with_ash(client)
    allow(client).to receive(:execute_raw)
      .with('echo test')
      .and_return(double(stdout: 'test', stderr: '', exit_status: 0))
    allow(client).to receive(:execute_raw)
      .with('test -x /bin/bash && echo OK')
      .and_return(double(stdout: '', stderr: '', exit_status: 1))
    allow(client).to receive(:execute_raw)
      .with('test -x /bin/sh && echo OK')
      .and_return(double(stdout: '', stderr: '', exit_status: 1))
    allow(client).to receive(:execute_raw)
      .with('test -x /bin/ash && echo OK')
      .and_return(double(stdout: 'OK', stderr: '', exit_status: 0))
  end

  # Mock a Windows container with cmd.exe
  # @param client [Object] The kubectl client to mock
  def mock_windows_container_with_cmd(client)
    allow(client).to receive(:execute_raw)
      .with('echo test')
      .and_return(double(stdout: '', stderr: 'not recognized', exit_status: 1))
    allow(client).to receive(:execute_raw)
      .with('where cmd.exe')
      .and_return(double(stdout: 'C:\\Windows\\System32\\cmd.exe', stderr: '', exit_status: 0))
  end

  # Mock a Windows container with PowerShell
  # @param client [Object] The kubectl client to mock
  def mock_windows_container_with_powershell(client)
    allow(client).to receive(:execute_raw)
      .with('echo test')
      .and_return(double(stdout: '', stderr: 'not recognized', exit_status: 1))
    allow(client).to receive(:execute_raw)
      .with('where cmd.exe')
      .and_return(double(stdout: '', stderr: '', exit_status: 1))
    allow(client).to receive(:execute_raw)
      .with('where powershell.exe')
      .and_return(double(stdout: 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe', stderr: '', exit_status: 0))
  end

  # Mock a distroless container (no shell available)
  # @param client [Object] The kubectl client to mock
  def mock_distroless_container(client)
    # OS detection succeeds (Unix) but no shells available
    allow(client).to receive(:execute_raw)
      .with('echo test')
      .and_return(double(stdout: 'test', stderr: '', exit_status: 0))
    # All shell checks fail
    allow(client).to receive(:execute_raw)
      .with(/test -x/)
      .and_return(double(stdout: '', stderr: '', exit_status: 1))
  end

  # Mock shell detection failure with exception
  # @param client [Object] The kubectl client to mock
  def mock_shell_detection_error(client)
    allow(client).to receive(:execute_raw)
      .and_raise(StandardError, 'Network error')
  end
end

RSpec.configure do |config|
  config.include ShellDetectionHelpers
end
