# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'train-k8s-container/version'

Gem::Specification.new do |spec|
  spec.name = 'train-k8s-container-mitre'
  spec.version = TrainPlugins::K8sContainer::VERSION
  spec.authors = ['MITRE SAF Team']
  spec.email = ['saf@groups.mitre.org']

  spec.summary = 'Train transport plugin for scanning Kubernetes containers with InSpec/Cinc Auditor.'
  spec.description = <<~DESC
    A Train transport plugin that enables Chef InSpec and Cinc Auditor to run compliance
    scans against containers running in Kubernetes clusters. Uses kubectl exec to execute
    commands inside containers, with proper platform detection for accurate OS resource behavior.
  DESC
  spec.homepage = 'https://github.com/mitre/train-k8s-container'
  spec.license = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.1'

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = 'https://github.com/mitre/train-k8s-container'
  spec.metadata['changelog_uri'] = 'https://github.com/mitre/train-k8s-container/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/mitre/train-k8s-container/issues'
  spec.metadata['documentation_uri'] = 'https://github.com/mitre/train-k8s-container#readme'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git])
    end
  end

  spec.require_paths = ['lib']

  # NOTE: Do not list 'train' or 'inspec' as dependencies.
  # Train plugins are loaded within InSpec's environment, which already provides
  # train, train-core, and all their dependencies. Declaring train as a dependency
  # causes gem activation conflicts (e.g., multi_json version conflicts).
  #
  # For development, add train to Gemfile in the development group.

  # Ruby 3.4+ will remove base64 from default gems - add it explicitly
  # This fixes the deprecation warning from train-core
  spec.add_dependency 'base64', '~> 0.2', '>= 0.2.0'
end
