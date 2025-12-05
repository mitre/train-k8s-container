# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

begin
  require 'cookstyle'
  require 'rubocop/rake_task'
  desc 'Run Cookstyle tests'
  RuboCop::RakeTask.new(:style) do |task|
    task.options += %w[--display-cop-names --no-color --parallel]
  end
rescue LoadError
  puts 'cookstyle gem is not installed. bundle install first to make sure all dependencies are installed.'
end

desc 'Run security scans (bundler-audit)'
task :security do
  require 'bundler/audit/task'
  Bundler::Audit::Task.new

  puts '=== Running Security Scans ==='
  puts '--- Bundler Audit (Dependency Vulnerabilities) ---'

  Rake::Task['bundle:audit:update'].invoke
  Rake::Task['bundle:audit'].invoke

  puts
  puts '✅ Security scans complete'
end

desc 'Run all quality checks (style + spec + security)'
task quality: %i[style spec security]

task default: :spec
