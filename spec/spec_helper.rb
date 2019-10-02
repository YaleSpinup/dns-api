require 'bundler/setup'
Bundler.require :default, :test

Sinatra::Application.set :environment, :test
Sinatra::Application.set :run, false
Sinatra::Application.set :raise_errors, true
Sinatra::Application.set :logging, false

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::RcovFormatter
]
SimpleCov.start

require File.join(File.dirname(__FILE__), '..', 'app.rb')
require File.join(File.dirname(__FILE__), '../lib', 'dns.rb')

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
