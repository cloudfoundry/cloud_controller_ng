module VCAP::Services::SSO::Commands
  class DeleteClientCommand
    attr_reader :client_id, :client_attrs

    def initialize(client_id)
      @client_id = client_id
      @client_attrs = { 'id' => client_id }
    end

    def uaa_command
      { action: 'delete' }
    end
  end
end
