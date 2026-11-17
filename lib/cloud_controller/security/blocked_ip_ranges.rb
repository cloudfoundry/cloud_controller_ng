require 'ipaddr'

module VCAP::CloudController
  module Security
    module BlockedIpRanges
      BLOCKED = [
        '127.0.0.0/8',       # IPv4 loopback
        '::1/128',           # IPv6 loopback
        '169.254.0.0/16',    # link-local / cloud metadata
        'fe80::/10',         # IPv6 link-local
        '10.0.0.0/8',        # RFC1918
        '172.16.0.0/12',     # RFC1918
        '192.168.0.0/16',    # RFC1918
        '0.0.0.0/8',         # IPv4 unspecified range
        '::/128',            # IPv6 unspecified
        '::ffff:0:0/96',     # IPv4-mapped IPv6
        '::/96',             # IPv4-compatible IPv6
        '2002::/16',         # 6to4
        'fc00::/7',          # IPv6 ULA
        '100.64.0.0/10',     # shared address space
        '224.0.0.0/4',       # IPv4 multicast
        'ff00::/8',          # IPv6 multicast
        '255.255.255.255/32', # limited broadcast
        '64:ff9b::/96',       # NAT64 well-known prefix (RFC 6052)
        '64:ff9b:1::/48'      # NAT64 local-use prefix (RFC 8215)
      ].map { |cidr| IPAddr.new(cidr) }.freeze

      NAT64_PREFIX_LENGTHS = [32, 40, 48, 56, 64, 96].freeze

      class InvalidNat64Prefix < StandardError; end

      # Parses a deployment-specific NAT64 prefix: an IPv6 CIDR with an RFC 6052 prefix length.
      def self.parse_nat64_prefix!(value)
        raise InvalidNat64Prefix.new('NAT64 prefix must be a string') unless value.is_a?(String)

        address, length, extra = value.split('/', -1)
        raise InvalidNat64Prefix.new('NAT64 prefix must be an IPv6 CIDR') if length.nil? || extra || !length.match?(/\A\d{1,3}\z/) || address.to_s.include?('%')
        raise InvalidNat64Prefix.new("NAT64 prefix length must be one of #{NAT64_PREFIX_LENGTHS.join(', ')}") unless NAT64_PREFIX_LENGTHS.include?(length.to_i)

        ip = IPAddr.new(value)
        raise InvalidNat64Prefix.new('NAT64 prefix must be an IPv6 CIDR') unless ip.ipv6?

        ip
      rescue IPAddr::Error
        raise InvalidNat64Prefix.new('NAT64 prefix must be an IPv6 CIDR'), cause: nil
      end

      # extra_nat64_prefixes: IPAddr objects (see parse_nat64_prefix!) or valid CIDR strings.
      def self.blocked?(addr_string, extra_nat64_prefixes=[])
        ip = IPAddr.new(addr_string)
        return true if BLOCKED.any? { |range| range.include?(ip) }

        extra_nat64_prefixes.any? do |prefix|
          prefix = parse_nat64_prefix!(prefix) unless prefix.is_a?(IPAddr)
          prefix.include?(ip)
        end
      rescue IPAddr::Error, InvalidNat64Prefix
        true # fail closed on unparseable input
      end
    end
  end
end
