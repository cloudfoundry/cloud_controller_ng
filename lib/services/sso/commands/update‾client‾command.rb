module VCAP::Services::SSO::Commands
  class UpdateClientCommand
    attr_reader :client_attrs

    def initialize(client_attrs)
      @client_attrs = client_attrs
    end

    def uaa_command
      { action: 'update,secret' }
    end
  end
end
