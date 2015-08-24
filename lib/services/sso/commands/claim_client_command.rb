module VCAP::Services::SSO::Commands
  class ClaimClientCommand
    attr_reader :client_id, :service_broker, :client_model_class

    def initialize(client_id, service_broker, client_model_class)
      @client_id = client_id
      @service_broker = service_broker
      @client_model_class = client_model_class
    end

    def db_command
      client_model_class.claim_client(client_id, service_broker)
    end
  end
end
