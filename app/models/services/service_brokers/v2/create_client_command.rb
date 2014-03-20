module VCAP::CloudController::ServiceBrokers::V2
  class CreateClientCommand
    attr_reader :client_attrs, :service_broker

    def initialize(opts)
      @client_attrs = opts.fetch(:client_attrs)
      @client_manager = opts.fetch(:client_manager)
      @service_broker = opts.fetch(:service_broker)
    end

    def apply!
      VCAP::CloudController::ServiceDashboardClient.claim_client_for_broker(
        client_attrs['id'],
        service_broker
      )
      client_manager.create(client_attrs)
    end

    private

    attr_reader :client_manager
  end
end
