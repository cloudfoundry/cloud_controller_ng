require 'spec_helper'

module VCAP::Services::UAA
  describe UpdateClientCommand do
    let(:client_attrs) do
      {
        'id' => 'client-id-1',
        'secret' => 'sekret',
        'redirect_uri' => 'https://foo.com'
      }
    end

    let(:service_broker) { VCAP::CloudController::ServiceBroker.make }

    let(:command) do
      UpdateClientCommand.new(
        client_attrs: client_attrs,
        service_broker: service_broker,
      )
    end

    describe '#uaa_command' do
      it 'renders the correct hash request to update in a UAA transaction' do
        expect(command.uaa_command).to eq({ action: 'update,secret' })
      end
    end

    describe '#db_command' do
      before do
        allow(VCAP::CloudController::ServiceDashboardClient).to receive(:claim_client_for_broker)
      end

      it 'claims the client in the DB' do
        command.db_command
        expect(VCAP::CloudController::ServiceDashboardClient).to have_received(:claim_client_for_broker)
      end
    end
  end
end
