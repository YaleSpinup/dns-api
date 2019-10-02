module DnsApi
  # Error handling
  module ErrorHandling
    class ApiError < StandardError; end
    class NotFound < ApiError; end
    class SchemaValidationError < ApiError; end

    # catch any exceptions from the app and return proper HTTP response
    def self.registered(app)
      app.set show_exceptions: false

      app.error do |err|
        DnsApi::Log.error "Caught exception: #{err.class} - #{err.inspect}"
        http_code = if defined? err.context
                      err.context.http_response.status_code || '500'
                    elsif defined? err.http_code
                      err.http_code
                    else
                      '500'
                    end
        Rack::Response.new(
          [{ 'error' => err.message }.to_json],
          http_code,
          'Content-type' => 'application/json'
        ).finish
      end
    end
  end
end
