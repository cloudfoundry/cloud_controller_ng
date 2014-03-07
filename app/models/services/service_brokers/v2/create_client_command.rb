module VCAP::CloudController::ServiceBrokers::V2
  class CreateClientCommand
    attr_reader :dashboard_client

    def initialize(dashboard_client, uaa_client)
      @dashboard_client = dashboard_client
      @uaa_client = uaa_client
    end

    def apply!
      uaa_client.create(dashboard_client)
    end

    private

    attr_reader :uaa_client
  end
end
