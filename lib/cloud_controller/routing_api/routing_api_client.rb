module VCAP::CloudController::RoutingApi
  class RoutingApiUnavailable < StandardError; end
  class UaaUnavailable < StandardError; end

  class Client
    attr_reader :skip_cert_verify, :routing_api_uri, :uaa_client

    ROUTER_GROUPS_PATH = '/routing/v1/router_groups'.freeze

    def initialize(routing_api_uri, uaa_client, skip_cert_verify)
      @routing_api_uri = URI(routing_api_uri) if routing_api_uri
      @uaa_client = uaa_client
      @skip_cert_verify = skip_cert_verify
    end

    def enabled?
      true
    end

    def router_groups
      raise RoutingApiUnavailable if @routing_api_uri.nil?
      client = HTTPClient.new
      client.ssl_config.set_default_paths
      use_ssl = routing_api_uri.scheme.to_s.downcase == 'https'
      routing_api_uri.path = ROUTER_GROUPS_PATH

      if use_ssl
        client.ssl_config.verify_mode = skip_cert_verify ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      end

      auth_header = { 'Authorization' => token_info.auth_header }
      response = client.get(routing_api_uri, nil, auth_header)
      unless response.ok?
        logger.error("routing api request for router groups failed: #{response.status} - #{response.body}")
        raise RoutingApiUnavailable
      end

      to_router_group_objects(response.body)
    end

    def router_group(guid)
      router_groups.find { |rtr_group| rtr_group.guid == guid }
    end

    def router_group_guid(name)
      router_groups.find do |rtr_group|
        if rtr_group.name == name
          return rtr_group.guid
        end
      end
    end

    private

    def to_router_group_objects(body)
      MultiJson.load(body).map do |hash|
        RouterGroup.new(hash)
      end
    rescue MultiJson::ParseError
      logger.error("routing api response parse failure: #{body}")
      raise RoutingApiUnavailable
    end

    def token_info
      uaa_client.token_info
    rescue CF::UAA::BadResponse => e
      logger.error("uaa request for token failed: #{e.inspect}")
      raise UaaUnavailable
    end

    def logger
      @logger ||= Steno.logger('cc.routing_api_client')
    end
  end
end
