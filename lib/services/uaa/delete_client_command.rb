module VCAP::Services::UAA
  class DeleteClientCommand
    attr_reader :client_id

    def initialize(opts)
      @client_id = opts.fetch(:client_id)
      @client_manager = opts.fetch(:client_manager)
    end

    def apply!
      client_manager.delete(client_id)
      VCAP::CloudController::ServiceDashboardClient.remove_claim_on_client(client_id)
    end

    private

    attr_reader :client_manager
  end
end
