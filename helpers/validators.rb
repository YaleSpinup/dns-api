module DnsApi
  module Helpers
    # various validation methods
    module Validators
      ##
      # returns true if the X-Auth-Token HTTP HEADER encrypted token is valid
      def valid_token?(htoken = nil)
        if htoken.nil?
          DnsApi::Log.error 'Validation failed: No token found in X-Auth-Token header! '
          halt 401, 'Token is required'.to_json
        end

        # get the key name itself for the config AUTH UUID
        xtoken = ''
        config_token = App.auth['token']
        config_token.is_a?(Hash) && config_token.any? { |key, _| xtoken = key }

        # compare the encrypted header token, it must derive from config token
        return true if BCrypt::Password.new(htoken) == xtoken

        DnsApi::Log.error 'Token validation failed: Invalid token! '
        halt 401, 'Invalid token'.to_json
      rescue BCrypt::Errors::InvalidHash
        DnsApi::Log.error 'Unable to authenticate request: token not a valid hash '
        halt 401, 'Token not a valid hash'.to_json
      end

      ##
      # Validates JSON parameters for POST/PUT requests against json-schema files.
      # Raises an exception when validation fails
      def schema_validate(schema, data)
        schema_file = "lib/json_schemas/#{schema}.json"
        DnsApi::Log.info 'Validating input against schema: ' + schema_file
        JSON::Validator.validate!(schema_file, data)
        DnsApi::Log.debug 'Schema is valid, returning data: ' + data.inspect
        data
      rescue JSON::Schema::ValidationError => e
        raise DnsApi::ErrorHandling::SchemaValidationError, 'JSON schema validation failed! ' + e.message
      rescue Errno::ENOENT => e
        raise DnsApi::ErrorHandling::ApiError, 'JSON schema file not found! ' + e.message
      end
    end
  end
end
