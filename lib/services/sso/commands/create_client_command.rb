module VCAP::Services::SSO::Commands
  class CreateClientCommand
    attr_reader :client_attrs

    def initialize(client_attrs)
      @client_attrs = client_attrs
    end

    def uaa_command
      { action: 'add' }
    end
  end
end
