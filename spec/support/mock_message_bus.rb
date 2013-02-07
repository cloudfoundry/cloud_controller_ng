class MockMessageBus
  attr_reader :config, :nats

  def initialize(config)
    @config = config
    @nats = config[:nats] || MockNATS
  end

  def subscribe(*args)
  end

  def register_components
  end

  def register_routes
  end

  def publish(*args)
  end
end
