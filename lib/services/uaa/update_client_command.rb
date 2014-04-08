module VCAP::Services::UAA
  class UpdateClientCommand
    attr_reader :client_attrs, :service_broker

    def initialize(opts)
      @client_attrs = opts.fetch(:client_attrs)
      @service_broker = opts.fetch(:service_broker)
    end

    def db_command
      client_id = client_attrs.fetch('id')

      VCAP::CloudController::ServiceDashboardClient.claim_client_for_broker(
        client_id,
        service_broker
      )
    end

    def uaa_command
      { action: 'update,secret' }
    end
  end
end
