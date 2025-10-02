# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

begin
  require 'cookstyle'
  require 'rubocop/rake_task'
  desc 'Run Cookstyle tests'
  RuboCop::RakeTask.new(:style) do |task|
    task.options += %w(--display-cop-names --no-color --parallel)
  end
rescue LoadError
  puts 'cookstyle gem is not installed. bundle install first to make sure all dependencies are installed.'
end

task default: :spec
