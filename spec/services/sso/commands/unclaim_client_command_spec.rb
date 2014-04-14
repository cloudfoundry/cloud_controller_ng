require 'spec_helper'

module VCAP::Services::SSO::Commands
  describe UnclaimClientCommand do
    let(:client_id) { 'client-id' }

    let(:command) { UnclaimClientCommand.new(client_id) }

    describe '#db_command' do
      before do
        allow(VCAP::CloudController::ServiceDashboardClient).to receive(:remove_claim_on_client)
      end

      it 'claims the client in the DB' do
        command.db_command
        expect(VCAP::CloudController::ServiceDashboardClient).to have_received(:remove_claim_on_client).with(client_id)
      end
    end
  end
end
