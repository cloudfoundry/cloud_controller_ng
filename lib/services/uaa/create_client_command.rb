module VCAP::Services::UAA
  class CreateClientCommand
    attr_reader :client_attrs, :service_broker

    def initialize(opts)
      @client_attrs = opts.fetch(:client_attrs)
      @client_manager = opts.fetch(:client_manager)
      @service_broker = opts.fetch(:service_broker)
    end

    def apply!
      client_id = client_attrs.fetch('id')

      VCAP::CloudController::ServiceDashboardClient.claim_client_for_broker(
        client_id,
        service_broker
      )
      client_manager.create(client_attrs)
    end

    private

    attr_reader :client_manager
  end
end
