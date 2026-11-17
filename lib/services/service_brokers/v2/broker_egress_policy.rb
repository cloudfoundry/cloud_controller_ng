require 'ipaddr'
require 'socket'
require 'cloud_controller/security/blocked_ip_ranges'
require_relative 'broker_url'

module VCAP::Services
  module ServiceBrokers::V2
    class BrokerEgressPolicy
      class DestinationDenied < StandardError; end
      class InvalidConfiguration < StandardError; end

      class ResolutionFailed < StandardError
        attr_reader :reason

        def initialize(reason)
          @reason = reason
          super("resolution failed: #{reason}")
        end
      end

      # Immutable result of a single resolution attempt.
      ValidatedDestination = Struct.new(:origin, :port, :addresses, keyword_init: true)

      # Only RFC1918, ULA, and shared address space may be granted exceptions; all others are always blocked.
      EXEMPTABLE_RANGES = [
        '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16',
        'fc00::/7', '100.64.0.0/10'
      ].map { |c| IPAddr.new(c) }.freeze
      private_constant :EXEMPTABLE_RANGES

      def self.from_config(config=VCAP::CloudController::Config.config)
        new(config.get(:broker_egress_allowed_private_destinations))
      end

      def self.validate_configuration!(allowed_private_destinations, blocked_nat64_prefixes)
        validate_exceptions!(allowed_private_destinations)
        validate_nat64_prefixes!(blocked_nat64_prefixes)
      end

      def initialize(allowed_private_destinations=[])
        @exceptions = parse_exceptions(allowed_private_destinations || [])
      end

      # Returns a ValidatedDestination or raises DestinationDenied / ResolutionFailed.
      def resolve_and_validate!(broker_url)
        addresses = resolve_addresses(broker_url.hostname)
        validate_addresses!(addresses, broker_url.origin)
        ValidatedDestination.new(origin: broker_url.origin, port: broker_url.port, addresses: addresses.freeze).freeze
      end

      private

      def resolve_addresses(hostname)
        result = Socket.getaddrinfo(hostname, nil, Socket::AF_UNSPEC, Socket::SOCK_STREAM).pluck(3)
        raise ResolutionFailed.new(:empty_result) if result.empty?

        result
      rescue SocketError
        raise ResolutionFailed.new(:socket_error)
      end

      def validate_addresses!(addresses, origin)
        addresses.each do |addr|
          next unless VCAP::CloudController::Security::BlockedIpRanges.blocked?(addr)
          raise DestinationDenied.new('destination resolved to a blocked address') unless exemptable?(addr) && exception_allows?(origin, addr)
        end
      end

      def exemptable?(addr_string)
        ip = IPAddr.new(addr_string)
        EXEMPTABLE_RANGES.any? { |range| range.include?(ip) }
      rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
        false
      end

      def exception_allows?(origin, addr)
        cidrs = @exceptions[origin]
        return false unless cidrs

        cidrs.any? { |cidr| cidr.include?(IPAddr.new(addr)) }
      rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
        false
      end

      def parse_exceptions(entries)
        entries.each_with_object({}) do |entry, h|
          next unless entry.is_a?(Hash) && entry['origin'] && entry['cidrs'].is_a?(Array)

          broker_url = BrokerUrl.parse!(entry['origin'])
          cidrs = entry['cidrs'].filter_map do |c|
            IPAddr.new(c)
          rescue IPAddr::Error
            nil
          end
          h[broker_url.origin] = cidrs
        rescue BrokerUrl::InvalidUrl
          # invalid origin entries silently skip at init; caller validates at config load
        end
      end

      def self.validate_exceptions!(entries)
        raise InvalidConfiguration.new('broker_egress_allowed_private_destinations must be an array') unless entries.is_a?(Array)

        seen_origins = {}
        entries.each do |entry|
          raise InvalidConfiguration.new('each exception must be a hash') unless entry.is_a?(Hash)

          origin = validate_exception_origin!(entry['origin'])
          raise InvalidConfiguration.new("duplicate exception origin: #{entry['origin']}") if seen_origins[origin]

          seen_origins[origin] = true
          validate_exception_cidrs!(entry['cidrs'])
        rescue BrokerUrl::InvalidUrl => e
          raise InvalidConfiguration.new("exception origin is invalid: #{e.message}")
        end
      end
      private_class_method :validate_exceptions!

      def self.validate_exception_origin!(origin_str)
        raise InvalidConfiguration.new('exception origin must be a string') unless origin_str.is_a?(String)

        BrokerUrl.parse!(origin_str).origin
      end
      private_class_method :validate_exception_origin!

      def self.validate_exception_cidrs!(cidrs)
        raise InvalidConfiguration.new('exception cidrs must be a non-empty array') unless cidrs.is_a?(Array) && !cidrs.empty?

        cidrs.each do |cidr|
          ip = IPAddr.new(cidr)
          raise InvalidConfiguration.new("cidr #{cidr} must lie within RFC1918, ULA, or shared address space") unless EXEMPTABLE_RANGES.any? { |r| r.include?(ip) }
        rescue IPAddr::Error
          raise InvalidConfiguration.new("cidr #{cidr} is invalid")
        end
      end
      private_class_method :validate_exception_cidrs!

      def self.validate_nat64_prefixes!(prefixes)
        raise InvalidConfiguration.new('broker_egress_blocked_nat64_prefixes must be an array') unless prefixes.is_a?(Array)

        prefixes.each do |prefix|
          VCAP::CloudController::Security::BlockedIpRanges.parse_nat64_prefix!(prefix)
        rescue VCAP::CloudController::Security::BlockedIpRanges::InvalidNat64Prefix => e
          raise InvalidConfiguration.new("invalid NAT64 prefix: #{e.message}")
        end
      end
      private_class_method :validate_nat64_prefixes!
    end
  end
end
