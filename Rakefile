require 'bundler'
Bundler.require
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

task default: [:rspec]

desc 'List all routes for this application'
task :routes do
  puts 'Showing all routes'
  puts `egrep -e namespace -e ' get |post |put |delete.*do$' routes/*.rb | sed 's/ do$//'`
end

desc 'Runs rspec tests'
RSpec::Core::RakeTask.new(:rspec) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end
