module VCAP::CloudController
  class TcpRouteValidator
    class ValidationError < StandardError
    end
    class DomainInvalid < ValidationError
    end
    class RouteInvalid < ValidationError
    end
    class RoutePortTaken < ValidationError
    end

    attr_reader :domain_guid, :port, :routing_api_client

    def initialize(routing_api_client, domain_guid, port)
      @domain_guid = domain_guid
      @port = port
      @routing_api_client = routing_api_client
    end

    def validate
      domain = Domain[guid: domain_guid]
      if domain.nil?
        raise DomainInvalid.new("Domain with guid #{domain_guid} does not exist")
      end

      if port.nil?
        if !domain.router_group_guid.nil?
          raise RouteInvalid.new('Router groups are only supported for TCP routes.')
        end
      else
        if domain.router_group_guid.nil?
          raise RouteInvalid.new('Port is supported for domains of TCP router groups only.')
        end

        router_group = routing_api_client.router_group(domain.router_group_guid)

        if router_group.nil? || router_group.type != 'tcp'
          raise RouteInvalid.new('Port is supported for domains of TCP router groups only.')
        end

        if port <= 0 || port > 65535
          raise RouteInvalid.new('Port must be greater than 0 and less than 65536.')
        end

        if port_taken?(port, domain.router_group_guid)
          raise RoutePortTaken.new(port_taken_error_message(port))
        end
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
