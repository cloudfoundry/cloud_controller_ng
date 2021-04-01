require 'socket'

class BackgroundJobEnvironment
  attr_reader :readiness_server

  def initialize(config)
    @config = config
    @log_counter = Steno::Sink::Counter.new

    VCAP::CloudController::StenoConfigurer.new(config.get(:logging)).configure do |steno_config_hash|
      steno_config_hash[:sinks] << @log_counter
    end

    @logger = Steno.logger('cc.background')
  end

  READINESS_SOCKET_QUEUE_DEPTH = 100

  def setup_environment(readiness_port=nil)
    VCAP::CloudController::DB.load_models(@config.get(:db), @logger)
    @config.configure_components

    if readiness_port && readiness_port > 0
      listen_on_readiness_port(readiness_port)
    end

    yield if block_given?
  end

  private

  def listen_on_readiness_port(port)
    @readiness_server = TCPServer.open('0.0.0.0', port)

    Thread.new do
      loop do
        Thread.start(@readiness_server.accept) do |c|
          c.puts 'ok'
          c.close
        end
      end
    rescue Errno::EBADF, IOError
      Thread.exit
    end
  end
end
