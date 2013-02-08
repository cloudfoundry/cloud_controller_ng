class MockMessageBus
  attr_reader :config, :nats

  def initialize(config)
    @config = config
    @nats = config[:nats] || MockNATS
  end

  def register_components
  end

  def register_routes
  end

  def subscribe(subject, opts = {}, &blk)
  end

  def publish(subject, message = nil)
  end

  def request(subject, data = nil, opts = {})
    []
  end
end
