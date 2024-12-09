require 'addressable/uri'

module VCAP::CloudController
  class ManifestRoute
    SUPPORTED_HTTP_SCHEMES = %w[http https unspecified].freeze
    SUPPORTED_TCP_SCHEMES = %w[tcp unspecified].freeze
    WILDCARD_HOST = '*'.freeze

    def self.parse(route, options=nil)
      parsed_uri = Addressable::URI.heuristic_parse(route, scheme: 'unspecified')

      attrs = if parsed_uri.nil?
                {}
              else
                parsed_uri.to_hash
              end

      attrs[:full_route] = route

      if options
        attrs[:options] = {}
        attrs[:options][:lb_algo] = options[:'loadbalancing-algorithm'] if options[:'loadbalancing-algorithm']
      end

      ManifestRoute.new(attrs)
    end

    def valid?
      if @attrs[:options] && !@attrs[:options].empty?
        return false if @attrs[:options].keys.any? { |key| RouteOptionsMessage::VALID_ROUTE_OPTIONS.exclude?(key) }
        return false if @attrs[:options][:lb_algo] && RouteOptionsMessage::VALID_LOADBALANCING_ALGORITHMS.exclude?(@attrs[:options][:lb_algo])
      end

      return false if @attrs[:host].blank?

      return SUPPORTED_TCP_SCHEMES.include?(@attrs[:scheme]) if @attrs[:port]

      SUPPORTED_HTTP_SCHEMES.include?(@attrs[:scheme])
    end

    def to_hash
      route = @attrs[:host]
      route_segments = route.split('.', 2)

      pairs = [
        {
          host: route_segments[0],
          domain: route_segments[1]
        }
      ]

      pairs.unshift(host: '', domain: route) unless route.start_with?(WILDCARD_HOST)

      {
        candidate_host_domain_pairs: pairs,
        port: @attrs[:port],
        path: @attrs[:path],
        options: @attrs[:options]
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
