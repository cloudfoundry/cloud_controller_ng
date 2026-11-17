require 'httpclient'

module HTTPClientMonkeyPatch
  module SocketConnectTimeout
    attr_reader :socket_connect_timeout

    def socket_connect_timeout=(timeout)
      @socket_connect_timeout = timeout
    end

    attr_accessor :broker_connection_context
  end

  module TCPSocketWithConnectTimeout
    def create_socket(host, port)
      @debug_dev << "! CONNECT TO #{host}:#{port}\n" if @debug_dev

      ctx = @client.broker_connection_context
      if ctx
        connect_host, connect_port = resolve_broker_address(ctx, host, port)
      else
        connect_host = host.delete('[]')
        connect_port = port
      end

      if @socket_local == HTTPClient::Site::EMPTY
        socket = TCPSocket.new(connect_host, connect_port, connect_timeout: @client.socket_connect_timeout)
      else
        clean_local = @socket_local.host.delete('[]')
        socket = TCPSocket.new(connect_host, connect_port, clean_local, @socket_local.port, connect_timeout: @client.socket_connect_timeout)
      end
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true) if @tcp_keepalive
      if @debug_dev
        @debug_dev << "! CONNECTION ESTABLISHED\n"
        socket.extend(HTTPClient::DebugSocket)
        socket.debug_dev = @debug_dev
      end
      socket
    rescue SystemCallError, SocketError => e
      raise e.exception(e.message + " (#{host}:#{port})")
    end

    private

    def resolve_broker_address(ctx, host, port)
      broker_url = ctx[:broker_url]
      policy     = ctx[:policy]

      expected = broker_url.hostname.delete('[]')
      raise SocketError.new("broker context hostname mismatch: expected #{expected}, got #{host}") unless host.delete('[]').downcase == expected

      destination = policy.resolve_and_validate!(broker_url)
      [destination.addresses.first, port]
    rescue VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::DestinationDenied,
           VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ResolutionFailed => e
      raise SocketError.new(e.message)
    end
  end
end

class HTTPClient
  prepend HTTPClientMonkeyPatch::SocketConnectTimeout
end

class HTTPClient::Session
  prepend HTTPClientMonkeyPatch::TCPSocketWithConnectTimeout
end
