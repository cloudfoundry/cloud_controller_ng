class BackgroundJobEnvironment
  def initialize(config)
    @config = config
    @log_counter = Steno::Sink::Counter.new
    @logger = Steno.logger('cc.background')

    VCAP::CloudController::StenoConfigurer.new(config.get(:logging)).configure do |steno_config_hash|
      steno_config_hash[:sinks] << @log_counter
    end
  end

  READINESS_SOCKET_QUEUE_DEPTH = 100

  def setup_environment(readiness_port=nil)
    VCAP::CloudController::DB.load_models(@config.get(:db), @logger)
    @config.configure_components

    if readiness_port && readiness_port > 0
      open_readiness_port(readiness_port)
      yield if block_given?
    end
  end

  private

  def open_readiness_port(port)
    # rubocop:disable Style/GlobalVars
    $socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM)
    sockaddr = Socket.pack_sockaddr_in(port, '127.0.0.1')
    $socket.bind(sockaddr)

    $socket.listen(READINESS_SOCKET_QUEUE_DEPTH)
    # rubocop:enable Style/GlobalVars
  end
end
