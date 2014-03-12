require 'spec_helper'
require 'models/services/service_brokers/v2/delete_client_command'

module VCAP::CloudController::ServiceBrokers::V2
  describe DeleteClientCommand do
    describe '#apply!' do
      let(:client_attrs) do
        {
          'id' => 'client-id-1',
          'secret' => 'sekret',
          'redirect_uri' => 'https://foo.com'
        }
      end

      let(:client) { double('client', destroy: nil)}

      let(:client_manager) { double(:client_manager, delete: nil) }

      let(:command) do
        DeleteClientCommand.new(
          client_id: 'client-id-1',
          client_manager: client_manager,
        )
      end

      before do
        allow(VCAP::CloudController::ServiceDashboardClient).
          to receive(:find).
          with(uaa_id: 'client-id-1').
          and_return(client)
      end

      it 'deletes the client in the UAA' do
        command.apply!
        expect(client_manager).to have_received(:delete).with('client-id-1')
      end

      it 'unclaims the client in the DB' do
        command.apply!
        expect(client).to have_received(:destroy)
      end
    end
  end
end
