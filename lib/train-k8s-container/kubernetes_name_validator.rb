# frozen_string_literal: true

module TrainPlugins
  module K8sContainer
    # Validates Kubernetes resource names to prevent injection attacks
    # Follows RFC 1123 DNS subdomain naming standard
    module KubernetesNameValidator
      # RFC 1123 DNS subdomain name:
      # - Lowercase alphanumeric characters, '-' or '.'
      # - Must start and end with alphanumeric
      # - Maximum 253 characters
      VALID_NAME_REGEX = /\A[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)?\z/
      MAX_NAME_LENGTH = 253

      # Validate a Kubernetes resource name (pod, namespace, container)
      # @param name [String] The name to validate
      # @param resource_type [String] Type of resource (for error messages)
      # @raise [ArgumentError] If name is invalid
      # @return [String] The validated name
      def self.validate!(name, resource_type: 'resource')
        raise ArgumentError, "#{resource_type} name cannot be nil" if name.nil?
        raise ArgumentError, "#{resource_type} name cannot be empty" if name.empty?

        raise ArgumentError, "#{resource_type} name too long (max #{MAX_NAME_LENGTH} chars): #{name}" if name.length > MAX_NAME_LENGTH

        unless VALID_NAME_REGEX.match?(name)
          raise ArgumentError, "Invalid #{resource_type} name '#{name}': must be RFC 1123 DNS subdomain " \
                               "(lowercase alphanumeric, '-' or '.', start/end with alphanumeric)"
        end

        name
      end

      # Check if name is valid without raising
      # @param name [String] The name to check
      # @return [Boolean] True if valid
      def self.valid?(name)
        return false if name.nil? || name.empty? || name.length > MAX_NAME_LENGTH

        VALID_NAME_REGEX.match?(name)
      end
    end
  end
end
