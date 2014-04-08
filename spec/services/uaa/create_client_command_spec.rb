require 'spec_helper'

module VCAP::Services::UAA
  describe CreateClientCommand do
    let(:client_attrs) do
      {
        'id' => 'client-id-1',
        'secret' => 'sekret',
        'redirect_uri' => 'https://foo.com'
      }
    end

    let(:broker) { double(:broker) }

    let(:command) do
      CreateClientCommand.new(
        client_attrs: client_attrs,
        service_broker: broker
      )
    end

    describe '#uaa_command' do
      it 'renders the correct hash request to create in a UAA transaction' do
        uaa_command = command.uaa_command
        expect(uaa_command).to eq({action: 'add'})
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
