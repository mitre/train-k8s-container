# frozen_string_literal: true

require_relative '../spec_helper'
require 'train'
require 'train-k8s-container/platform'
require 'train-k8s-container/version'
require 'train-k8s-container/shell_detector'

# Test connection class that includes Platform module with mocked command execution
# Train's Detect.scan runs commands through run_command which calls run_command_via_connection
class TestPlatformConnection < Train::Plugins::Transport::BaseConnection
  include TrainPlugins::K8sContainer::Platform

  attr_accessor :command_results

  def initialize
    super({})
    @command_results = {}
  end

  private

  # This is called by Train's run_command method during platform detection
  # Train's detection runs many commands like 'uname -s', 'test -f /etc/os-release && cat /etc/os-release', etc.
  def run_command_via_connection(cmd, &)
    result = @command_results[cmd]
    return result if result

    # Default to failure for unmocked commands (simulates file not found)
    Train::Extras::CommandResult.new('', '', 1)
  end
end

RSpec.describe TrainPlugins::K8sContainer::Platform do
  subject { TestPlatformConnection.new }

  # Helper to mock command results for Ubuntu detection
  # Train's detection sequence for Debian/Ubuntu:
  # 1. Windows checks first (cmd.exe /c ver, Get-WmiObject)
  # 2. uname -s (returns "Linux")
  # 3. uname -m (architecture)
  # 4. test -f /etc/debian_version (just existence check for Debian family)
  # 5. test -f /etc/os-release && cat /etc/os-release (parse OS info)
  # 6. test -f /etc/lsb-release && cat /etc/lsb-release (additional Ubuntu info)
  def mock_ubuntu_detection(connection)
    connection.command_results = {
      # Windows detection (must fail for Linux)
      'cmd.exe /c ver' => Train::Extras::CommandResult.new('', 'not found', 1),
      'Get-WmiObject Win32_OperatingSystem | Select Caption,Version | ConvertTo-Json' =>
        Train::Extras::CommandResult.new('', 'not found', 1),
      'show version' => Train::Extras::CommandResult.new('', 'not found', 1),
      'version' => Train::Extras::CommandResult.new('', 'not found', 1),
      # Unix/Linux detection
      'uname -s' => Train::Extras::CommandResult.new('Linux', '', 0),
      'uname -r' => Train::Extras::CommandResult.new('5.15.0', '', 0),
      'uname -m' => Train::Extras::CommandResult.new('x86_64', '', 0),
      # Debian family detection (file existence check)
      'test -f /etc/debian_version' => Train::Extras::CommandResult.new('', '', 0),
      # OS release info
      'test -f /etc/os-release && cat /etc/os-release' =>
        Train::Extras::CommandResult.new(<<~OS_RELEASE, '', 0),
          NAME="Ubuntu"
          VERSION="22.04.3 LTS (Jammy Jellyfish)"
          ID=ubuntu
          ID_LIKE=debian
          VERSION_ID="22.04"
          PRETTY_NAME="Ubuntu 22.04.3 LTS"
        OS_RELEASE
      # LSB release for Ubuntu
      'test -f /etc/lsb-release && cat /etc/lsb-release' =>
        Train::Extras::CommandResult.new(<<~LSB_RELEASE, '', 0),
          DISTRIB_ID=Ubuntu
          DISTRIB_RELEASE=22.04
          DISTRIB_CODENAME=jammy
          DISTRIB_DESCRIPTION="Ubuntu 22.04.3 LTS"
        LSB_RELEASE
    }
  end

  # Helper to mock command results for Alpine detection
  # Alpine is detected via /etc/alpine-release file
  def mock_alpine_detection(connection)
    connection.command_results = {
      # Windows detection (must fail for Linux)
      'cmd.exe /c ver' => Train::Extras::CommandResult.new('', 'not found', 1),
      'Get-WmiObject Win32_OperatingSystem | Select Caption,Version | ConvertTo-Json' =>
        Train::Extras::CommandResult.new('', 'not found', 1),
      'show version' => Train::Extras::CommandResult.new('', 'not found', 1),
      'version' => Train::Extras::CommandResult.new('', 'not found', 1),
      # Unix/Linux detection
      'uname -s' => Train::Extras::CommandResult.new('Linux', '', 0),
      'uname -r' => Train::Extras::CommandResult.new('5.15.0', '', 0),
      'uname -m' => Train::Extras::CommandResult.new('x86_64', '', 0),
      # OS release info
      'test -f /etc/os-release && cat /etc/os-release' =>
        Train::Extras::CommandResult.new(<<~OS_RELEASE, '', 0),
          NAME="Alpine Linux"
          ID=alpine
          VERSION_ID=3.18.4
          PRETTY_NAME="Alpine Linux v3.18"
        OS_RELEASE
      # Alpine-specific release file
      'test -f /etc/alpine-release && cat /etc/alpine-release' =>
        Train::Extras::CommandResult.new('3.18.4', '', 0),
      'test -f /etc/alpine-release' => Train::Extras::CommandResult.new('', '', 0),
    }
  end

  describe '#platform' do
    before do
      # Reset Train's platform registry to avoid accumulation from previous tests
      Train::Platforms.__reset
    end

    context 'with Ubuntu container' do
      before do
        mock_ubuntu_detection(subject)
      end

      it 'detects ubuntu as the platform name' do
        expect(subject.platform.name).to eq('ubuntu')
      end

      it 'detects debian as the family' do
        expect(subject.platform[:family]).to eq('debian')
      end

      it 'includes linux family' do
        expect(subject.platform.linux?).to be true
      end

      it 'includes unix family' do
        expect(subject.platform.unix?).to be true
      end

      it 'detects the correct release' do
        expect(subject.platform[:release]).to eq('22.04')
      end

      # Kubernetes/container context families
      it 'includes kubernetes in family hierarchy' do
        expect(subject.platform.family_hierarchy).to include('kubernetes')
      end

      it 'includes container in family hierarchy' do
        expect(subject.platform.family_hierarchy).to include('container')
      end

      it 'has kubernetes? method that returns true' do
        expect(subject.platform.kubernetes?).to be true
      end

      it 'has container? method that returns true' do
        expect(subject.platform.container?).to be true
      end
    end

    context 'with Alpine container' do
      before do
        mock_alpine_detection(subject)
      end

      it 'detects alpine as the platform name' do
        expect(subject.platform.name).to eq('alpine')
      end

      # NOTE: Train's platform detection puts Alpine directly under linux family
      # so platform[:family] returns 'linux', but platform.alpine? returns true
      it 'is in the linux family' do
        expect(subject.platform[:family]).to eq('linux')
      end

      it 'includes linux family' do
        expect(subject.platform.linux?).to be true
      end

      it 'detects alpine via platform helper method' do
        expect(subject.platform.alpine?).to be true
      end

      # Kubernetes/container context families work regardless of OS type
      it 'includes kubernetes in family hierarchy' do
        expect(subject.platform.family_hierarchy).to include('kubernetes')
      end

      it 'includes container in family hierarchy' do
        expect(subject.platform.family_hierarchy).to include('container')
      end

      it 'has kubernetes? method that returns true' do
        expect(subject.platform.kubernetes?).to be true
      end

      it 'has container? method that returns true' do
        expect(subject.platform.container?).to be true
      end
    end
  end

  describe '#add_k8s_families' do
    before do
      Train::Platforms.__reset
    end

    it 'registers kubernetes family with Train' do
      mock_ubuntu_detection(subject)
      subject.platform
      expect(Train::Platforms.families).to have_key('kubernetes')
    end

    it 'registers container family with Train' do
      mock_ubuntu_detection(subject)
      subject.platform
      expect(Train::Platforms.families).to have_key('container')
    end

    it 'preserves original OS family hierarchy' do
      mock_ubuntu_detection(subject)
      hierarchy = subject.platform.family_hierarchy
      # Original hierarchy should still be present
      expect(hierarchy).to include('debian')
      expect(hierarchy).to include('linux')
      expect(hierarchy).to include('unix')
      expect(hierarchy).to include('os')
    end
  end
end
