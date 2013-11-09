require 'socket'
require 'loggregator_messages/log_message.pb'

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
      while true
        begin
          stuff = @sock.recv(65536)
          envelope = LogEnvelope.decode(stuff)
          messages << envelope.log_message
        rescue Beefcake::Message::WrongTypeError, Beefcake::Message::RequiredFieldNotSetError,  Beefcake::Message::InvalidValueError => e
          puts "ERROR"
          puts e
        end

      end
    end
  end

  def stop(number_expected_messages)
    max_tries = 0
    while messages.length < number_expected_messages
      sleep 0.2
      max_tries += 1
      break if max_tries > 10
    end
    @sock.close

    Thread.kill(@thread)
  end
end
