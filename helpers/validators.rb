module DnsApi
  module Helpers
    # various validation methods
    module Validators
      # returns true if the given encrypted token is valid for the given request action (GET, POST, etc)
      def valid_token?(htoken = nil, action = nil)
        return false if htoken.nil?

        token = BCrypt::Password.new(htoken)
        App.auth['token'].each_key do |t|
          return App.auth['token'][t].include?(action) if token == t
        end

        DnsApi::Log.warn('Unable to authenticate request: invalid token')
        false
      rescue BCrypt::Errors::InvalidHash
        DnsApi::Log.warn('Unable to authenticate request: token not a valid hash')
        false
      end

      ##
      # Validates JSON parameters for POST/PUT requests against json-schema files.
      # Raises an exception when validation fails
      def schema_validate(schema, data)
        schema_file = "lib/json_schemas/#{schema}.json"
        DnsApi::Log.info "Validating input against schema: #{schema_file}"
        JSON::Validator.validate!(schema_file, data)
        DnsApi::Log.debug "Schema is valid, returning data: #{data.inspect}"
        data
      rescue JSON::Schema::ValidationError => e
        raise DnsApi::ErrorHandling::SchemaValidationError, "JSON schema validation failed! #{e.message}"
      rescue Errno::ENOENT => e
        raise DnsApi::ErrorHandling::ApiError, "JSON schema file not found! + #{e.message}"
      end
    end
  end
end
