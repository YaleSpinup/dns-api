module DnsApi
  # Interact with a Proteus Client
  class Proteus
    require 'netaddr'

    DEFAULT_TYPES = [
      ::Proteus::Types::GENERICRECORD,
      ::Proteus::Types::EXTERNALHOST,
      ::Proteus::Types::HOSTRECORD,
      ::Proteus::Types::MXRECORD,
      ::Proteus::Types::TXTRECORD,
      ::Proteus::Types::CNAMERECORD,
      ::Proteus::Types::HINFORECORD,
      ::Proteus::Types::SRVRECORD,
      ::Proteus::Types::IP4ADDRESS,
      ::Proteus::Types::MACADDRESS
    ].freeze

    def initialize(conf)
      @config = OpenStruct.new(conf)
      DnsApi::Log.debug 'Logging into Proteus'
      client = ::Proteus::Client.new(@config.to_h).login!
      @client = client
      ObjectSpace.define_finalizer(self, self.class.finalize(client))
    end

    def self.finalize(client)
      proc { client.logout! }
    end

    def alias_records(params)
      params[:offset] ||= 0
      params[:limit] ||= 10
      options = []
      options.push(params[:hint].nil? ? nil : "hint=#{params[:hint]}")
      @client.get_aliases_by_hint(params[:offset], params[:limit], options.compact.join('|'))
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    # Assigns the next available IP
    # Gets the network from a given CIDR or Network ID
    def assign_ip(body)
      DnsApi::Log.debug "Assigning IP from payload #{body.inspect}"
      body['network_id'] ||= network_from_cidr(body['cidr'])
      raise ::DnsApi::ErrorHandling::ApiError unless body['network_id']

      # hostname, viewId, reverseFlag, sameAsZoneFlag
      ip = @client.assign_next_available_ip4_address(
        @client.get_entities.first.id,
        body['network_id'],
        body['mac'],
        build_host_info(body),
        'MAKE_STATIC',
        build_properties(body)
      )

      DnsApi::Log.debug "IP object returned from proteus: #{ip.inspect}"
      {
        id: ip[:id],
        ip: decompose_properties(ip[:properties])['address'],
        name: ip[:name]
      }
    end

    def build_host_info(body)
      "#{body['hostname']},#{@config.viewid},#{body['reverse']},false"
    end

    def build_properties(body)
      properties = "name=#{body['hostname']}"
      properties += "|#{body['properties']}" unless body['properties'].nil?
      properties
    end

    def create_record(body)
      body['ttl'] ||= 300
      body['properties'] ||= ''
      case body['type']
      when ::Proteus::Types::CNAMERECORD
        @client.add_alias_record(body['record'], body['target'], body['ttl'], body['properties'])
      when ::Proteus::Types::EXTERNALHOST
        @client.add_external_host_record(body['record'], body['properties'])
      when ::Proteus::Types::HOSTRECORD
        @client.add_host_record(body['record'], body['target'], body['ttl'] || 300, body['properties'])
      else
        DnsApi::Log.error("Unexpexted type in create_record: #{body['type']}")
        raise ::DnsApi::ErrorHandling::ApiError, 'Bad type.'
      end
    end

    ##
    # Custom search based on entity type (one of the ::Proteus::Types) and list of filters
    def custom_search(filters, type)
      DnsApi::Log.debug "Custom search for type: #{type}, filters: #{filters.split('|').inspect}"
      @client.custom_search(filters.split('|'), type)
    end

    def decompose_properties(properties)
      Hash[properties.split('|').collect { |p| p.split('=') }]
    end

    ##
    # Delete entity using ID
    def delete(id)
      @client.delete(id)
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    ##
    # Delete record using IP4ADDRESS type
    def delete_ip(ip_addr)
      @client.delete(ipv4_address(ip_addr).id)
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    def entity(id, types = DEFAULT_TYPES)
      object = @client.get_entity_by_id(id)
      raise DnsApi::ErrorHandling::NotFound if object.nil? || (!types.nil? && !types.include?(object.type))
      object
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    def external_host_records(params)
      params[:offset] ||= 0
      params[:limit] ||= 10
      if params[:name]
        [@client.get_entity_by_name(@config.viewid, params[:name], params[:type])]
      elsif params[:keyword]
        @client.search_by_object_types(params[:keyword], params[:type], params[:offset], params[:limit])
      else
        @client.get_entities(@config.viewid, params[:type], params[:offset], params[:limit])
      end
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    def host_records(params)
      params[:offset] ||= 0
      params[:limit] ||= 10
      options = []
      options.push(params[:hint].nil? ? nil : "hint=#{params[:hint]}")
      @client.get_host_records_by_hint(params[:offset], params[:limit], options.compact.join('|'))
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    def ipv4_address(ip_addr)
      DnsApi::Log.info "Getting IP address object from Proteus using #{ip_addr}"
      config_id = @client.get_entities.first.id
      ipv4 = @client.get_ip4_address(config_id, ip_addr)
      raise DnsApi::ErrorHandling::NotFound if ipv4.type.nil?
      ipv4
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    def networks(params)
      params[:offset] ||= 0
      params[:limit] ||= 10
      options = []
      options.push(params[:hint].nil? ? nil : "hint=#{params[:hint]}")
      config_id = @client.get_entities.first.id
      @client.get_ip4_networks_by_hint(config_id, params[:offset], params[:limit], options.compact.join('|'))
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    def network_from_cidr(cidr)
      raise ::DnsApi::ErrorHandling::ApiError unless cidr
      NetAddr::CIDR.create(cidr).enumerate.first(10).each do |ip|
        begin
          DnsApi::Log.info "Trying to use IP address #{ip} as canary"
          parent = parent_id(ipv4_address(ip).id)
          return parent
        rescue DnsApi::ErrorHandling::NotFound => e
          DnsApi::Log.info "Rescuing assign IP from payload #{e.inspect}"
          next
        end
      end
    end

    def parent_id(id)
      @client.get_parent(id).id
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    def records(params)
      case params[:type]
      when ::Proteus::Types::HOSTRECORD
        host_records(params)
      when ::Proteus::Types::CNAMERECORD
        alias_records(params)
      when ::Proteus::Types::EXTERNALHOST
        external_host_records(params)
      else
        raise ::DnsApi::ErrorHandling::ApiError, 'Bad or missing record type specified.'
      end
    end

    def zones(params)
      params[:offset] ||= 0
      params[:limit] ||= 10
      options = []
      options.push(params[:hint].nil? ? nil : "hint=#{params[:hint]}")
      config_id = @client.get_entities.first.id
      @client.get_zones_by_hint(config_id, params[:offset], params[:limit], options.compact.join('|'))
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    def create_mac(mac)
      DnsApi::Log.info "Creating MAC address object on Proteus for #{mac}"
      mac['properties'] ||= ''
      @client.add_mac_address(mac['mac'], mac['properties'])
      @client.associate_mac_address_with_pool(mac['mac'], mac['macpool']) unless mac['macpool'].nil?
    end

    def mac_address(mac)
      DnsApi::Log.info "Getting MAC address object from Proteus for #{mac}"
      mac = @client.get_mac_address(mac)
      raise DnsApi::ErrorHandling::NotFound if mac.type.nil?
      mac
    rescue ::Proteus::ApiEntityError::EntityNotFound
      raise DnsApi::ErrorHandling::NotFound
    end

    def update_mac(mac, body)
      DnsApi::Log.info "Updating MAC address object on Proteus for #{mac}"
      @client.associate_mac_address_with_pool(mac, body['macpool']) unless body['macpool'].nil?
      @client.update_properties(mac_address(mac).id, body['properties']) unless body['properties'].nil?
    end
  end
end
