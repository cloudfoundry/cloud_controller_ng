module MessageBus
  class Configurer
    def initialize(config={})
      @config = config
    end

    def go
      CfMessageBus::MessageBus.new(@config)
    end
  end
end
