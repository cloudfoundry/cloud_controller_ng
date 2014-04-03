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

    let(:client_manager) { double(:client_manager, create: nil) }
    let(:broker) { double(:broker) }

    before do
      allow(VCAP::CloudController::ServiceDashboardClient).to receive(:claim_client_for_broker)
      allow(VCAP::CloudController::ServiceDashboardClient).to receive(:remove_claim_on_client)
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

      context 'when claiming the client for the broker fails' do
        before do
          allow(VCAP::CloudController::ServiceDashboardClient).to receive(:claim_client_for_broker).and_raise
        end

        it 'does not create the UAA client' do
          command.apply! rescue nil
          expect(client_manager).not_to have_received(:create)
        end
      end

      context 'when creating the client in UAA fails' do
        before do
          allow(client_manager).to receive(:create).and_raise
        end

        it 'does not remove the claim' do
          command.apply! rescue nil
          expect(VCAP::CloudController::ServiceDashboardClient).to_not have_received(:remove_claim_on_client).
            with('client-id-1')
        end
      end
    end
  end
end
