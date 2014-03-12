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

    let(:client_manager) { double(:client_manager, create: nil) }
    let(:broker) { double(:broker) }

    before do
      allow(VCAP::CloudController::ServiceDashboardClient).to receive(:claim_client_for_broker)
    end

    let(:command) do
      CreateClientCommand.new(
        client_attrs: client_attrs,
        client_manager: client_manager,
        service_broker: broker
      )
    end

    describe '#apply!' do
      it 'creates the client in the UAA' do
        command.apply!
        expect(client_manager).to have_received(:create).with(client_attrs)
      end

      it 'claims the client in the DB' do
        command.apply!
        expect(VCAP::CloudController::ServiceDashboardClient).to have_received(:claim_client_for_broker)
      end
    end
  end
end
