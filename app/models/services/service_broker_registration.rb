module VCAP::CloudController
  class ServiceBrokerRegistration
    attr_reader :broker

    def initialize(broker)
      @broker = broker
    end

    def save(options = {})
      ensure_no_raise_on_failure!(options)

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

    def ensure_no_raise_on_failure!(options)
      # By default, Sequel::Model raises exceptions when it encounters
      # validation errors. Historically, we have caught these exceptions
      # to trigger our error handling. However, exceptions shouldn't be
      # used for flow control, so we're trying to move away from raising
      # on failure.
      #
      # Until this is globally disabled, we require that the option to
      # disable it be explicitly passed in. This ensures an interface
      # consistent with Sequel::Model.
      raise 'raising on failure deprecated' if raise_on_failure?(options)
    end

    def raise_on_failure?(options)
      options.fetch(:raise_on_failure, Sequel::Model.raise_on_save_failure) == true
    end
  end
end
