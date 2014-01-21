module VCAP::CloudController
  class ServiceBrokerRegistration
    attr_reader :broker

    def initialize(broker)
      @broker = broker
    end

    def save
      if broker.valid?
        broker.db.transaction(savepoint: true) do
          broker.save
          broker.load_catalog
        end
        self
      end
    end

    def errors
      broker.errors
    end
  end
end
