require 'uri'

module VCAP
  module Services
    module ServiceBrokers
      module V2
        # Immutable, HTTPS-only parse of a service broker URL. Error messages never echo the input.
        class BrokerUrl
          class InvalidUrl < StandardError; end

          attr_reader :hostname, :origin, :port, :scheme, :uri

          def self.parse!(url_string)
            new(url_string)
          end

          private_class_method :new

          def initialize(url_string)
            raise InvalidUrl.new('url must be a string') unless url_string.is_a?(String)
            raise InvalidUrl.new('url must not contain whitespace or control characters') if url_string.match?(/[[:space:][:cntrl:]]/)

            parsed = parse_uri(url_string)

            raise InvalidUrl.new('url must use https') unless parsed.scheme&.downcase == 'https'
            raise InvalidUrl.new('url must be absolute with a hostname') if parsed.host.nil? || parsed.host.empty?
            raise InvalidUrl.new('url must not contain authentication') if parsed.userinfo
            raise InvalidUrl.new('url must not contain a fragment') unless parsed.fragment.nil?

            effective_port = parsed.port || 443
            raise InvalidUrl.new('url port must be between 1 and 65535') unless (1..65_535).cover?(effective_port)

            host = parsed.host.downcase
            @scheme   = 'https'.freeze
            @hostname = parsed.hostname.downcase.freeze
            @port     = effective_port
            @origin   = (effective_port == 443 ? "https://#{host}" : "https://#{host}:#{effective_port}").freeze
            @uri      = deep_freeze(parsed)
            freeze
          end

          private

          def parse_uri(url_string)
            URI.parse(url_string)
          rescue URI::InvalidURIError
            raise InvalidUrl.new('url is not a valid URI'), cause: nil
          end

          def deep_freeze(uri)
            uri.instance_variables.each do |name|
              value = uri.instance_variable_get(name)
              value.freeze if value.is_a?(String)
            end
            uri.freeze
          end
        end
      end
    end
  end
end
