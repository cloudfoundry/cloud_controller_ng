require 'socket'
require 'sonde'

class FakeLoggregatorServer
  attr_reader :messages, :port, :sock

  def initialize(port)
    @messages = []
    @port = port
    @sock = UDPSocket.new
  end

  def start
    @sock.bind('localhost', port)

    @thread = Thread.new do
      loop do
        stuff = @sock.recv(65536)
        envelope = ::Sonde::Envelope.decode(stuff)
        messages << envelope.logMessage
      rescue Beefcake::Message::WrongTypeError, Beefcake::Message::RequiredFieldNotSetError, Beefcake::Message::InvalidValueError => e
        puts 'ERROR'
        puts e
      end
    end
  end

  def stop
    Thread.kill(@thread)
    @sock.close
  end
end
