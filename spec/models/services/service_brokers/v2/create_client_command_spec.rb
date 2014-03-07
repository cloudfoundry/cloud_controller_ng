require 'spec_helper'

module VCAP::CloudController::ServiceBrokers::V2
  describe CreateClientCommand do
    let(:client_attrs) do
      {
        'id' => 'client-id-1',
        'secret' => 'sekret',
        'redirect_uri' => 'https://foo.com'
      }
    end

    let(:uaa_client) { double(:uaa_client, create: nil) }

    let(:command) { CreateClientCommand.new(client_attrs, uaa_client) }

    describe '#apply!' do
      it 'creates the client in the UAA' do
        command.apply!
        expect(uaa_client).to have_received(:create).with(client_attrs)
      end
    end
  end
end
