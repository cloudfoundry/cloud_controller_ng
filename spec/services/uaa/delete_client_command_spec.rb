require 'spec_helper'

module VCAP::Services::UAA
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
        allow(VCAP::CloudController::ServiceDashboardClient).to receive(:remove_claim_on_client)
      end

      it 'deletes the client in the UAA' do
        command.apply!
        expect(client_manager).to have_received(:delete).with('client-id-1')
      end

      it 'unclaims the client in the DB' do
        command.apply!
        expect(VCAP::CloudController::ServiceDashboardClient).to have_received(:remove_claim_on_client).
          with('client-id-1')
      end

      context 'when deleting the UAA client fails' do
        before do
          allow(client_manager).to receive(:delete).and_raise
        end

        it 'does not remove the claim on the client' do
          command.apply! rescue nil
          expect(VCAP::CloudController::ServiceDashboardClient).not_to have_received(:remove_claim_on_client)
        end
      end
    end
  end
end
