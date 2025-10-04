# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/ansi_sanitizer'

RSpec.describe TrainPlugins::K8sContainer::AnsiSanitizer do
  describe '.sanitize' do
    it 'removes CSI sequences (colors, cursor movement)' do
      input = "\e[31mRed text\e[0m"
      expect(described_class.sanitize(input)).to eq('Red text')
    end

    it 'removes OSC sequences (terminal title)' do
      input = "\e]0;Window Title\atrue content"
      expect(described_class.sanitize(input)).to eq('true content')
    end

    it 'removes cursor movement sequences' do
      input = "Line1\e[ALine2\e[C"
      expect(described_class.sanitize(input)).to eq('Line1Line2')
    end

    it 'removes erase line sequences' do
      input = "Some text\e[Kmore text"
      expect(described_class.sanitize(input)).to eq('Some textmore text')
    end

    it 'normalizes Windows line endings' do
      input = "Line1\r\nLine2\r\nLine3"
      expect(described_class.sanitize(input)).to eq("Line1\nLine2\nLine3")
    end

    it 'normalizes Mac line endings' do
      input = "Line1\rLine2\rLine3"
      expect(described_class.sanitize(input)).to eq("Line1\nLine2\nLine3")
    end

    it 'handles nil input' do
      expect(described_class.sanitize(nil)).to eq('')
    end

    it 'handles empty input' do
      expect(described_class.sanitize('')).to eq('')
    end

    it 'handles mixed ANSI sequences and line endings' do
      input = "\e[32mGreen\e[0m\r\n\e[1;33mYellow Bold\e[0m\r"
      expect(described_class.sanitize(input)).to eq("Green\nYellow Bold\n")
    end

    it 'handles nested escape sequences' do
      input = "\e[1m\e[31mBold Red\e[0m\e[0m"
      expect(described_class.sanitize(input)).to eq('Bold Red')
    end

    it 'preserves plain text without sequences' do
      input = 'Plain text with no escapes'
      expect(described_class.sanitize(input)).to eq('Plain text with no escapes')
    end
  end
end
