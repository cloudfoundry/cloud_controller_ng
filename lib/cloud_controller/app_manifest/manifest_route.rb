require 'addressable/uri'

module VCAP::CloudController
  class ManifestRoute
    SUPPORTED_HTTP_SCHEMES = %w{http https unspecified}.freeze
    SUPPORTED_TCP_SCHEMES = %w{tcp unspecified}.freeze
    WILDCARD_HOST = '*'.freeze

    def self.parse(string)
      parsed_uri = Addressable::URI.heuristic_parse(string, scheme: 'unspecified')

      if parsed_uri.nil?
        attrs = {}
      else
        attrs = parsed_uri.to_hash
      end

      attrs[:full_route] = string
      ManifestRoute.new(attrs)
    end

    def valid?
      return false if @attrs[:host].blank?

      if @attrs[:port]
        return SUPPORTED_TCP_SCHEMES.include?(@attrs[:scheme])
      end

      SUPPORTED_HTTP_SCHEMES.include?(@attrs[:scheme])
    end

    def to_hash
      route = @attrs[:host]

      route_segments = route.split('.', 2)
      potential_host = route_segments[0]

      if route.start_with?(WILDCARD_HOST)
        potential_domains = [route_segments[1]]
      else
        potential_domains = CloudController::DomainDecorator.new(route).intermediate_domains.
          map(&:name).sort_by(&:length).reverse
      end

      {
        potential_host: potential_host,
        potential_domains: potential_domains,
        port: @attrs[:port],
        path: @attrs[:path]
      }
    end

    def to_s
      @attrs[:full_route]
    end

    private

    def initialize(attrs)
      @attrs = attrs
    end
  end
end
