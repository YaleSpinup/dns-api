source 'https://rubygems.org'

gem 'json'
gem 'json-schema'
gem 'logger'
gem 'netaddr', '~> 1.5', '>= 1.5.1'
gem 'proteus', git: 'https://github.com/YaleUniversity/proteus_client.git'
gem 'rake'
gem 'require_all'
gem 'sinatra'
gem 'sinatra-contrib', require: 'sinatra/contrib/all'
gem 'sinatra-cross_origin', require: 'sinatra/cross_origin'

group :development do
  gem 'rubocop'
  gem 'shotgun'
end

group :test do
  gem 'rack-test', require: 'rack/test'
  gem 'rspec'
  gem 'rspec_junit_formatter'
  gem 'simplecov'
  gem 'simplecov-rcov'
end

group :production do
  gem 'puma'
end
