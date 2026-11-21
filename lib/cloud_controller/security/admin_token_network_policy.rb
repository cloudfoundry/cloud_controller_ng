require 'ipaddr'
require 'socket'

module VCAP
  module CloudController
    module Security
      class AdminTokenNetworkPolicy
        ADMIN_SCOPES = %w[uaa.admin cloud_controller.admin cloud_controller.admin_read_only cloud_controller.global_auditor].freeze

        def initialize(options={}, nginx_socket: nil)
          @enabled = options.fetch(:enabled, false)
          @networks = options.fetch(:allowed_cidrs, []).map { |cidr| network(cidr) }
          @trusted_proxies = options.fetch(:trusted_proxies, []).map { |cidr| network(cidr) }
          @additional_scopes = options.fetch(:additional_protected_scopes, [])
          @nginx_socket = nginx_socket
        end

        def allowed?(token, env)
          return true unless @enabled && protected_token?(token)

          address = source_address(env)
          address && @networks.any? { |cidr| cidr.include?(address) }
        end

        private

        def protected_token?(token)
          %w[scope authorities].any? do |claim|
            values = token[claim].is_a?(String) ? token[claim].split(/[ ,]+/) : Array(token[claim])
            values.any? { |scope| ADMIN_SCOPES.include?(scope) || @additional_scopes.include?(scope) || (scope.is_a?(String) && scope.match?(/\Azones\..+\.admin\z/)) }
          end
        end

        def source_address(env)
          peer = peer_address(env)
          return nil unless peer
          return peer unless trusted?(peer)

          forwarded_header = env.fetch('HTTP_X_FORWARDED_FOR', '')
          return nil unless forwarded_header.is_a?(String)

          forwarded = forwarded_header.split(',', -1)
          return nil if forwarded.size > 64

          forwarded.reverse_each do |value|
            address = literal(value.strip)
            return nil unless address
            return address unless trusted?(address)
          end
          nil
        end

        def peer_address(env)
          socket = env['puma.socket']
          # Only Nginx on the configured, access-controlled Unix socket may assert X-Real-IP.
          # A loopback REMOTE_ADDR alone is NOT evidence of Unix-socket transport.
          if @nginx_socket && socket && socket.local_address.unix? && socket.local_address.unix_path == @nginx_socket
            literal(env['HTTP_X_REAL_IP'])
          elsif socket
            literal(socket.remote_address.ip_address)
          else
            literal(env['REMOTE_ADDR'])
          end
        rescue IOError, SystemCallError, SocketError
          nil
        end

        def trusted?(address)
          @trusted_proxies.any? { |cidr| cidr.include?(address) }
        end

        def literal(value)
          return nil unless value.is_a?(String) && value.match?(/\A[0-9a-fA-F:.]+\z/)

          address = IPAddr.new(value)
          address.ipv4_mapped? ? address.native : address
        rescue IPAddr::Error
          nil
        end

        def network(cidr)
          parts = cidr.split('/', -1)
          address = literal(parts.first)
          valid_prefix = parts.size == 1 || (parts.size == 2 && parts.last.match?(/\A[0-9]{1,3}\z/) &&
            parts.last.to_i <= (address&.ipv4? ? 32 : 128) && !(parts.first.include?(':') && address&.ipv4?))
          raise ArgumentError.new("Invalid administrative token network CIDR: #{cidr}") unless address && valid_prefix

          parts.size == 1 ? address : address.mask(parts.last.to_i)
        end
      end
    end
  end
end
