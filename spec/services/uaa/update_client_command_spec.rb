require 'spec_helper'

module VCAP::Services::UAA
  describe UpdateClientCommand do
    describe '#apply!' do
      let(:client_attrs) do
        {
          'id' => 'client-id-1',
          'secret' => 'sekret',
          'redirect_uri' => 'https://foo.com'
        }
      end

      let(:service_broker) { VCAP::CloudController::ServiceBroker.make }

      let(:client_manager) { double(:client_manager, update: nil) }

      let(:command) do
        UpdateClientCommand.new(
          client_attrs: client_attrs,
          client_manager: client_manager,
          service_broker: service_broker,
        )
      end

      before do
        allow(VCAP::CloudController::ServiceDashboardClient).to receive(:claim_client_for_broker)
      end

      it 'updates the client in the UAA' do
        command.apply!
        expect(client_manager).to have_received(:update).with(client_attrs)
      end

      it 'claims the client in the DB' do
        command.apply!
        expect(VCAP::CloudController::ServiceDashboardClient).to have_received(:claim_client_for_broker)
      end
    end
  end
end
