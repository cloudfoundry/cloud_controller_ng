module VCAP::CloudController::ServiceBrokers::V2
  class UpdateClientCommand
    attr_reader :client_attrs

    def initialize(opts)
      @client_attrs = opts.fetch(:client_attrs)
      @client_manager = opts.fetch(:client_manager)
    end

    def apply!
      client_manager.update(client_attrs)
    end

    private

    attr_reader :client_manager
  end
end
