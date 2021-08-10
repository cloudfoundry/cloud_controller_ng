module VCAP::CloudController
  class RouteUpdateDestinationsMessage < BaseMessage
    def initialize(params, replace: false)
      super(params)
      @replace = replace
    end

    register_allowed_keys [:destinations]

    validates_with NoAdditionalKeysValidator

    validate :destinations_valid?

    def destinations_array
      new_route_mappings = []
      destinations.each do |dst|
        app_guid = HashUtils.dig(dst, :app, :guid)
        process_type = HashUtils.dig(dst, :app, :process, :type) || 'web'
        weight = HashUtils.dig(dst, :weight)
        protocol = HashUtils.dig(dst, :protocol)

        new_route_mappings << {
          app_guid: app_guid,
          process_type: process_type,
          app_port: dst[:port],
          weight: weight,
          protocol: protocol,
        }
      end

      new_route_mappings
    end

    private

    ERROR_MESSAGE = 'Destinations must have the structure "destinations": [{"app": {"guid": "app_guid"}}]'.freeze

    def destinations_valid?
      minimum = @replace ? 0 : 1

      unless destinations.is_a?(Array) && (minimum..100).cover?(destinations.length)
        errors.add(:destinations, "must be an array containing between #{minimum} and 100 destination objects.")
        return
      end

      validate_destination_contents
    end

    def validate_destination_contents
      app_to_ports_hash = {}

      destinations.each_with_index do |dst, index|
        unless dst.is_a?(Hash)
          add_destination_error(index, 'must be an object.')
          next
        end

        unless dst.key?(:app)
          add_destination_error(index, 'must have an "app".')
          next
        end

        unless (dst.keys - [:app, :weight, :port, :protocol]).empty?
          add_destination_error(index, 'must have only "app" and optionally "weight", "port" or "protocol".')
          next
        end

        validate_app(index, dst[:app])
        validate_weight(index, dst[:weight])
        validate_port(index, dst[:port])
        validate_protocol(index, dst[:protocol])

        app_to_ports_hash[dst[:app]] ||= []
        app_to_ports_hash[dst[:app]] << dst[:port]
      end

      app_to_ports_hash.each do |_, port_array|
        if port_array.length > 10
          errors.add(:process, 'must have at most 10 exposed ports.')
          break
        end
      end

      return unless errors.empty?

      validate_weights(destinations)
    end

    def validate_weight(destination_index, weight)
      return unless weight

      unless @replace
        add_destination_error(destination_index, 'weighted destinations can only be used when replacing all destinations.')
        return
      end

      unless weight.is_a?(Integer) && weight > 0 && weight <= 100
        add_destination_error(destination_index, 'weight must be a positive integer between 1 and 100.')
      end
    end

    def validate_protocol(destination_index, protocol)
      return unless protocol

      unless protocol.is_a?(String) && RouteMappingModel::VALID_PROTOCOLS.include?(protocol)
        add_destination_error(destination_index, "protocol must be 'http1', 'http2' or 'tcp'.")
      end
    end

    def validate_port(destination_index, port)
      return unless port

      unless port.is_a?(Integer) && port >= 1024 && port <= 65535
        add_destination_error(destination_index, 'port must be a positive integer between 1024 and 65535 inclusive.')
      end
    end

    def validate_weights(destinations)
      weights = destinations.map { |d| d.is_a?(Hash) && d[:weight] }

      return if weights.all?(&:nil?)

      if weights.any?(&:nil?)
        errors.add(:destinations, 'cannot contain both weighted and unweighted destinations.')
        return
      end

      if weights.sum != 100
        errors.add(:destinations, 'must have weights that sum to 100.')
      end
    end

    def validate_app(destination_index, app)
      unless app.is_a?(Hash) && valid_guid?(app[:guid])
        add_destination_error(destination_index, 'app must have the structure {"guid": "app_guid"}')
        return
      end

      unless valid_process?(app[:process])
        add_destination_error(destination_index, 'process must have the structure {"type": "process_type"}')
      end
    end

    def valid_process?(process)
      return true if process.nil?

      process.is_a?(Hash) && process.keys == [:type] && process[:type].is_a?(String) && !process[:type].empty?
    end

    def valid_guid?(guid)
      guid.is_a?(String) && (1...200).cover?(guid.size)
    end

    def add_destination_error(index, message)
      errors.add("Destinations[#{index}]:", message)
    end
  end
end
