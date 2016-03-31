module VCAP::CloudController
  class RouteValidator
    class ValidationError < StandardError
    end
    class DomainInvalid < ValidationError
    end
    class RouteInvalid < ValidationError
    end
    class RoutePortTaken < ValidationError
    end

    attr_reader :domain_guid, :port, :host, :path, :domain

    def initialize(routing_api_client, domain_guid, route_attrs)
      @routing_api_client = routing_api_client
      @domain_guid = domain_guid
      @port = route_attrs['port']
      @host = route_attrs['host']
      @path = route_attrs['path']
      @domain = Domain[guid: domain_guid]
    end

    def validate
      validate_domain_existance

      if is_tcp_router_group?
        validate_host_not_included
        validate_path_not_included
        validate_port_included
        validate_port_not_taken
        validate_port_number
      else
        validate_port_not_included
      end
    end

    private

    def routing_api_client
      raise RoutingApi::Client::RoutingApiDisabled if @routing_api_client.nil?
      @routing_api_client
    end

    def is_tcp_router_group?
      domain.router_group_guid && !router_group.nil? && router_group.type == 'tcp'
    end

    def router_group
      @router_group ||= routing_api_client.router_group(domain.router_group_guid)
    end

    def validate_host_not_included
      unless host.blank?
        raise RouteInvalid.new('Host and path are not supported, as domain belongs to a TCP router group.')
      end
    end

    def validate_path_not_included
      unless path.blank?
        raise RouteInvalid.new('Host and path are not supported, as domain belongs to a TCP router group.')
      end
    end

    def validate_port_included
      if port.nil?
        raise RouteInvalid.new('For TCP routes you must specify a port or request a random one.')
      end
    end

    def validate_port_not_included
      if !!port
        raise RouteInvalid.new('Port is supported for domains of TCP router groups only.')
      end
    end

    def validate_domain_existance
      if domain.nil?
        raise DomainInvalid.new("Domain with guid #{domain_guid} does not exist")
      end
    end

    def validate_port_number
      raise RouteInvalid.new('Port must be one of the reservable ports.') unless router_group.reservable_ports.include? port
    end

    def validate_port_not_taken
      if port_taken?(port, domain.router_group_guid)
        raise RoutePortTaken.new(port_taken_error_message(port))
      end
    end

    def port_taken?(port, router_group_guid)
      domains = Route.dataset.select_all(Route.table_name).
                join(Domain.table_name, id: :domain_id).
                where(:"#{Domain.table_name}__router_group_guid" => router_group_guid,
                      :"#{Route.table_name}__port" => port)

      domains.count > 0
    end

    def port_taken_error_message(port)
      "Port #{port} is not available on this domain's router group. " \
        'Try a different port, request an random port, or ' \
        'use a domain of a different router group.'
    end
  end
end
