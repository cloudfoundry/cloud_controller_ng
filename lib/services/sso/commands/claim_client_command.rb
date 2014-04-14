module VCAP::Services::SSO::Commands
  class ClaimClientCommand
    attr_reader :client_id, :service_broker

    def initialize(client_id, service_broker)
      @client_id = client_id
      @service_broker = service_broker
    end

    def db_command
      VCAP::CloudController::ServiceDashboardClient.claim_client_for_broker(client_id, service_broker)
    end
  end
end
