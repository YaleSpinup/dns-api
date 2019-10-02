module DnsApi
  module Helpers
    # various validation methods
    module Validators
      ##
      # Validates given token and returns true if token matches the digest
      def valid_token?(token = nil, action = nil)
        digest = token.nil? ? nil : Digest::SHA512.hexdigest(token)
        App.auth['token512'].key?(digest) && App.auth['token512'][digest].include?(action)
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
