# frozen_string_literal: true

# Shim file for gem name compatibility
# The gem is named 'train-k8s-container-mitre' for RubyGems publishing,
# but the internal library structure uses 'train-k8s-container'.
# This allows `require 'train-k8s-container-mitre'` to work when
# InSpec/Cinc loads the plugin by gem name.

require_relative 'train-k8s-container'
