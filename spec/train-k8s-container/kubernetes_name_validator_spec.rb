# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/kubernetes_name_validator'

RSpec.describe TrainPlugins::K8sContainer::KubernetesNameValidator do
  describe '.validate!' do
    it 'accepts valid lowercase names' do
      expect(described_class.validate!('my-pod', resource_type: 'pod')).to eq('my-pod')
    end

    it 'accepts names with dots' do
      expect(described_class.validate!('my-pod.test', resource_type: 'pod')).to eq('my-pod.test')
    end

    it 'accepts names with numbers' do
      expect(described_class.validate!('pod-123', resource_type: 'pod')).to eq('pod-123')
    end

    it 'rejects nil names' do
      expect do
        described_class.validate!(nil, resource_type: 'pod')
      end.to raise_error(ArgumentError, /cannot be nil/)
    end

    it 'rejects empty names' do
      expect do
        described_class.validate!('', resource_type: 'pod')
      end.to raise_error(ArgumentError, /cannot be empty/)
    end

    it 'rejects uppercase letters' do
      expect do
        described_class.validate!('MyPod', resource_type: 'pod')
      end.to raise_error(ArgumentError, /RFC 1123/)
    end

    it 'rejects names starting with hyphen' do
      expect do
        described_class.validate!('-invalid', resource_type: 'pod')
      end.to raise_error(ArgumentError, /RFC 1123/)
    end

    it 'rejects names ending with hyphen' do
      expect do
        described_class.validate!('invalid-', resource_type: 'pod')
      end.to raise_error(ArgumentError, /RFC 1123/)
    end

    it 'rejects special characters' do
      expect do
        described_class.validate!('pod@name', resource_type: 'pod')
      end.to raise_error(ArgumentError, /RFC 1123/)
    end

    it 'rejects names with spaces' do
      expect do
        described_class.validate!('pod name', resource_type: 'pod')
      end.to raise_error(ArgumentError, /RFC 1123/)
    end

    it 'rejects injection attempts with semicolons' do
      expect do
        described_class.validate!('pod; rm -rf /', resource_type: 'pod')
      end.to raise_error(ArgumentError, /RFC 1123/)
    end

    it 'rejects injection attempts with pipes' do
      expect do
        described_class.validate!('pod | whoami', resource_type: 'pod')
      end.to raise_error(ArgumentError, /RFC 1123/)
    end

    it 'rejects names exceeding 253 characters' do
      long_name = 'a' * 254
      expect do
        described_class.validate!(long_name, resource_type: 'pod')
      end.to raise_error(ArgumentError, /too long/)
    end

    it 'accepts names exactly 253 characters' do
      # Valid: starts/ends with letter, contains hyphens
      long_name = "a#{'-a' * 125}b" # = 253 chars
      expect(described_class.validate!(long_name, resource_type: 'pod')).to eq(long_name)
    end
  end

  describe '.valid?' do
    it 'returns true for valid names' do
      expect(described_class.valid?('my-pod-123')).to be true
    end

    it 'returns false for invalid names' do
      expect(described_class.valid?('Invalid')).to be false
      expect(described_class.valid?('-invalid')).to be false
      expect(described_class.valid?(nil)).to be false
      expect(described_class.valid?('')).to be false
    end
  end
end
