module VCAP::CloudController::Models
  class ServiceBrokerRegistration
    delegate :guid, :created_at, :updated_at, :name, :broker_url, :token, to: :broker

    attr_reader :broker

    def initialize(attrs)
      @broker = ServiceBroker.new(attrs.stringify_keys.slice('name', 'broker_url', 'token'))
    end

    def save(options = {})
      ensure_no_raise_on_failure!(options)

      if valid?
        broker.save
        self
      end
    end

    def errors
      @errors ||= Sequel::Model::Errors.new
    end

    private

    def valid?
      errors.clear

      if broker.valid?
        broker.check!
        true
      else
        broker.errors.each do |key, broker_errors|
          broker_errors.each do |broker_error|
            errors.add(key, broker_error)
          end
        end
        false
      end
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
