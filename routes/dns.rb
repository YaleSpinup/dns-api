module DnsApi
  module Routes
    # API /vX/dns routes
    class DNS < Sinatra::Base
      require 'ostruct'
      require 'netaddr'
      require_all 'lib/*.rb'
      require_all 'helpers/*.rb'

      configure do
        set :root, App.root
        set :show_exceptions, false
        enable :cross_origin
        register Sinatra::Namespace
        register DnsApi::ErrorHandling
        helpers DnsApi::Helpers::Validators
        DnsApi::Log.log_level = App.dns['log_level'] unless App.dns['log_level'].nil?
      end

      configure :production do
        DnsApi::Log.log_level = 'INFO'
      end

      before do
        content_type :json
        path_info = request.env['PATH_INFO']
        method = request.env['REQUEST_METHOD']
        htoken = request.env['HTTP_X_AUTH_TOKEN']
        DnsApi::Log.debug("Processing request: #{method} #{path_info}")
        halt 401, 'Invalid token'.to_json unless (%w[/v1/dns/ping /v1/dns/version].include? path_info) || valid_token?(htoken)
        response.headers['Access-Control-Allow-Origin'] = '*'
      end

      after %r{/v1/dns/(?!ping)} do
        DnsApi::Log.debug("Responded to request with #{response.status}: #{response.body.inspect}")
      end

      # DNS API v1
      namespace '/v1/dns' do
        options '*' do
          response.headers['Allow'] = 'GET, POST, PUT, OPTIONS'
          response.headers['Access-Control-Allow-Headers'] = 'X-Auth-Token, Content-Type, Accept'
          response.headers['Access-Control-Allow-Origin'] = '*'
          200
        end

        get '/ping' do
          [200, 'pong']
        end

        get '/version' do
          [200, { version: VERSION }.to_json]
        end

        # GET all managed DNS accounts
        get '/?' do
          App.dns['accounts'].keys.to_json
        end

        # Proteus custom search
        # Query parameters are :
        #   type: the type of record, e.g. MACAddress, IP4Address
        #   filters: list of pipe-separated filters, e.g. filters=reg_by=NETID|host_type=Windows
        get '/:account/search' do
          validate_account! params[:account]
          halt 400, 'Bad request: no filters parameter specified' if params[:filters].nil?
          halt 400, 'Bad request: no type parameter specified' if params[:type].nil?
          supported_types = ::Proteus::Types.constants(false).map(&::Proteus::Types.method(:const_get))
          unless supported_types.include? params[:type]
            halt 400, "Bad request: unknown type: #{params[:type]}. Supported types are #{supported_types}"
          end
          client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
          client.custom_search(params[:filters], params[:type]).collect(&:to_h).to_json
        end

        # GET _any_ object by [proteus] id
        get '/:account/id/:id' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.entity(params[:id]).to_h.to_json
          rescue DnsApi::ErrorHandling::NotFound
            halt 404, 'Not found'.to_json
          end
        end

        # DELETE _any_ object by [proteus] id
        delete '/:account/id/:id' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.delete(params[:id])
          rescue DnsApi::ErrorHandling::NotFound
            halt 404, 'Not Found'.to_json
          end
        end

        # GET a list of zones available in the account
        #  Note: The maximum number of records available from the
        #   Proteus API is 10, which is lame but life.
        #
        # Query parameters are :
        #   offset: index in the list to use as the starting point (default: 0)
        #   limit: maximum number of records to return (default: 10)
        #   hint: a string to narrow the list of results (ie. its.yale.edu)
        get '/:account/zones' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.zones(params).collect(&:to_h).to_json
          rescue DnsApi::ErrorHandling::ApiError
            [].to_json
          end
        end

        # GET a zone by [proteus] id
        get '/:account/zones/:id' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.entity(params[:id], [::Proteus::Types::ZONE]).to_h.to_json
          rescue DnsApi::ErrorHandling::NotFound
            halt 404, 'Not found'.to_json
          end
        end

        # GET a list of networks available in the account
        #  Note: The maximum number of records available from the
        #   Proteus API is 10, which is lame but life.
        #
        # Query parameters are :
        #   offset: index in the list to use as the starting point (default: 0)
        #   limit: maximum number of records to return (default: 10)
        #   hint: a string to narrow the list of results (ie. 192.168.123)
        get '/:account/networks' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.networks(params).collect(&:to_h).to_json
          rescue DnsApi::ErrorHandling::NotFound
            [].to_json
          rescue DnsApi::ErrorHandling::ApiError => e
            halt 400, "Bad request: #{e.message}".to_json
          end
        end

        # Get a network by [proteus] id
        get '/:account/networks/:id' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.entity(params[:id], [::Proteus::Types::IP4NETWORK]).to_h.to_json
          rescue DnsApi::ErrorHandling::NotFound
            halt 404, 'Not found'.to_json
          end
        end

        # GET a list of dns records
        # The records endpoint expects a 'type' query parameter which corresponds to which type of
        # records to return.  Currently I don't think it makes sense to return all records of all types
        # and this is not easily supported by the proteus API anyways.
        #
        # All types support the 'limit' and 'offset' parameters:
        #   limit: the maximum number of records to return (currently limited to 10 by proteus)
        #   offset: the record number to use as the starting point
        #
        # For each record type, there are different query params:
        # Host:
        #   hint: ^abc
        #     *Note:* Not specifying a hint, seems to return a list of all host records
        #     If the hint option is not specified, searching criteria will be based on the same as zone
        #     host record. The following wildcards are supported in the hint option.
        #       * ^-matches the beginning of a string.
        #       * $-matches the end of a string.
        #       * ?-matches any one character.
        #       * *-matches one or more characters within a string.
        #     hint=* or omitting the hint altogether returns all records (paged by limit and offset)
        # Alias:
        #   hint: ^abc
        #     *Note:* Not specifying a hint, seems to always return 'null' for the Alias type
        #     If the hint option is not specified, searching criteria will be based on the same as zone
        #     alias. The following wildcards are supported in the hint option.
        #       * ^-matches the beginning of a string.
        #       * $-matches the end of a string.
        #       * ?-matches any one character.
        #       * -matches one or more characters within a string.
        #     hint=* appears to return all Alias records (paged by limit and offset).  YMMV.
        # External:
        #   The following query parameters are supported, evaluated in the following order:
        #       * name: external host record name
        #       * keyword: searches for a keyword
        #       * none: will return all external records (paged by limit and offset)
        get '/:account/records' do
          validate_account! params[:account]
          begin
            rec = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config']).records(params)
            raise DnsApi::ErrorHandling::NotFound if rec.nil? || rec == []

            rec.collect(&:to_h).to_json
          rescue DnsApi::ErrorHandling::NotFound
            [].to_json
          rescue DnsApi::ErrorHandling::ApiError => e
            halt 400, "Bad request: #{e.message}"
          end
        end

        # Create a DNS record
        post '/:account/records' do
          validate_account! params[:account]
          begin
            body = schema_validate(:create, request_body)
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.create_record(body)
          rescue DnsApi::ErrorHandling::SchemaValidationError => e
            halt 422, "Unprocessable Entity: JSON schema validation failed: (#{e.message})".to_json
          end
        end

        # GET a record by [proteus] id
        get '/:account/records/:id' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.entity(params[:id]).to_h.to_json
          rescue DnsApi::ErrorHandling::NotFound
            halt 404, 'Not found'.to_json
          end
        end

        put '/:account/records/:id' do
          validate_account! params[:account]
          halt 501, 'Not Implemented'
        end

        delete '/:account/records/:id' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.delete(params[:id])
          rescue DnsApi::ErrorHandling::NotFound
            halt 404, 'Not Found'.to_json
          end
        end

        post '/:account/ips' do
          validate_account! params[:account]
          begin
            body = schema_validate(:assign_ip, request_body)
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.assign_ip(body).to_json
          rescue DnsApi::ErrorHandling::ApiError => e
            halt 422, "Bad request (#{e.message})".to_json
          rescue DnsApi::ErrorHandling::SchemaValidationError => e
            halt 422, "Unprocessable Entity: JSON schema validation failed: (#{e.message})".to_json
          end
        end

        # GET list of available CIDR subnets where we can assign IPs
        # this allows us to provide a curated list of subnets per account instead of all IP ranges from Proteus
        get '/:account/ips/cidrs' do
          validate_account! params[:account]
          halt 500, 'CIDR file not defined' if App.dns['accounts'][params[:account]]['cidr_file'].nil?
          File.read(App.dns['accounts'][params[:account]]['cidr_file'])
        end

        # GET an ip
        get '/:account/ips/:ip' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.ipv4_address(params[:ip]).to_h.to_json
          rescue DnsApi::ErrorHandling::NotFound
            halt 404, 'Not found'.to_json
          end
        end

        put '/:account/ips/:id' do
          validate_account! params[:account]
          halt 501, 'Not Implemented'
        end

        delete '/:account/ips/:ip' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.delete_ip(params[:ip])
          rescue DnsApi::ErrorHandling::NotFound
            halt 404, 'Not Found'.to_json
          end
        end

        # Create a MAC record
        post '/:account/macs' do
          validate_account! params[:account]
          begin
            body = schema_validate(:create_mac, request_body)
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.create_mac(body).to_json
          rescue DnsApi::ErrorHandling::SchemaValidationError => e
            halt 422, "Unprocessable Entity: JSON schema validation failed: (#{e.message})".to_json
          end
        end

        # Get record by MAC address
        get '/:account/macs/:mac' do
          validate_account! params[:account]
          begin
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.mac_address(params[:mac]).to_h.to_json
          rescue DnsApi::ErrorHandling::NotFound
            halt 404, 'Not found'.to_json
          end
        end

        # Update MAC record macpool/properties
        put '/:account/macs/:mac' do
          validate_account! params[:account]
          begin
            body = schema_validate(:update_mac, request_body)
            halt 400, 'Bad request: required parameter(s) not specified' if body['macpool'].nil? && body['properties'].nil?
            client = DnsApi::Proteus.new(App.dns['accounts'][params[:account]]['config'])
            client.update_mac(params[:mac], body)
            halt 204
          rescue DnsApi::ErrorHandling::NotFound
            halt 404, 'Not found'.to_json
          end
        end
      end

      def validate_account!(account)
        halt 404, "Unknown DNS account: #{account}".to_json unless App.dns['accounts'].keys.include? account
      end

      def request_body
        halt 400, 'Bad Request'.to_json if request.body.nil?
        request.body.rewind
        jsonbody = request.body.read
        halt 400, 'Bad Request'.to_json if jsonbody.size.zero?
        DnsApi::Log.debug("Got JSON params: #{jsonbody}")
        JSON.parse jsonbody
      end
    end
  end
end
