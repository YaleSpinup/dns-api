# App: the DnsApi Sinatra app
class App < Sinatra::Application
  register Sinatra::Contrib
  register Sinatra::ConfigFile

  set :logging, true
  set :show_exceptions, false
  set :root, File.dirname(__FILE__)

  config_file 'config/config.yml'

  configure :development do
    config_file 'config/config.yml.erb'
  end

  configure :test do
    config_file 'config/config.test.yml'
  end

  configure :production do
    set :dump_errors, false
  end

  require_all 'routes/*.rb'

  # mount all routes you wish to use
  use DnsApi::Routes::DNS

  # common error responses
  not_found do
    'Requested resource not found!'.to_json
  end
end
