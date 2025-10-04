# frozen_string_literal: true

source 'https://rubygems.org'

# train-core is needed for development/testing but NOT declared in gemspec
# Train plugins are loaded within InSpec's environment which provides train
gem 'train-core', ['>= 1.7.5', '< 4.0']

# Specify your gem's dependencies in train-k8s-container.gemspec
gemspec

group :development do
  gem 'bundler-audit', '~> 0.9'
  gem 'cookstyle', '~> 8.1'
  gem 'rake', '~> 13.0', '>= 13.0.6'
  gem 'rspec', '~> 3.11'
end

group :test do
  gem 'byebug'
  gem 'pry'
  gem 'simplecov', require: false
end
