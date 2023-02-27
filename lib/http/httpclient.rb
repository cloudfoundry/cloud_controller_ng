require 'httpclient'

module HTTPClientMonkeyPatch
  module SocketConnectTimeout
    attr_reader :socket_connect_timeout

    def socket_connect_timeout=(timeout)
      @socket_connect_timeout = timeout
    end
  end

  module TCPSocketWithConnectTimeout
    def create_socket(host, port)
      @debug_dev << "! CONNECT TO #{host}:#{port}\n" if @debug_dev
      clean_host = host.delete('[]')
      if @socket_local == HTTPClient::Site::EMPTY
        socket = TCPSocket.new(clean_host, port, connect_timeout: @client.socket_connect_timeout)
      else
        clean_local = @socket_local.host.delete('[]')
        socket = TCPSocket.new(clean_host, port, clean_local, @socket_local.port, connect_timeout: @client.socket_connect_timeout)
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
  end
end

class HTTPClient
  prepend HTTPClientMonkeyPatch::SocketConnectTimeout
end

class HTTPClient::Session
  prepend HTTPClientMonkeyPatch::TCPSocketWithConnectTimeout
end
