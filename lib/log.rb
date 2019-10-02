module DnsApi
  # Log class
  class Log

    LEVELS = %w[debug info warn error fatal unknown].freeze
    # the default log level
    @@log_level = 'DEBUG'

    def self.log_level=(loglevel)
      @@log_level = loglevel.upcase
    end

    def self.method_missing(method_sym, *args, &block)
      if LEVELS.include?(method_sym.to_s)
        if @logger.nil?
          @logger = Logger.new(STDOUT)
          @logger.level = Object.const_get("Logger::#{@@log_level}")
          @logger.datetime_format = '%Y-%m-%d %H:%M:%S '
        end
        @logger.send(method_sym, *args, &block)
      else
        super
      end
    end

    def self.respond_to_missing?(method_sym, include_private = false)
      if LEVELS.include?(method_sym.to_s)
        true
      else
        super
      end
    end

  end
end
