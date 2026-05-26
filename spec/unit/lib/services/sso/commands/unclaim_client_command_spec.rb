require 'lightweight_spec_helper'

module VCAP::Services; end
module VCAP::Services::SSO; end

require 'services/sso/commands/unclaim_client_command'

module VCAP::Services::SSO::Commands
  RSpec.describe UnclaimClientCommand do
    let(:client_id) { 'client-id' }

    let(:command) { UnclaimClientCommand.new(client_id) }

    describe '#db_command' do
      before do
        stub_const('VCAP::CloudController::ServiceDashboardClient', Class.new)
        allow(VCAP::CloudController::ServiceDashboardClient).to receive(:release_client)
      end

      it 'claims the client in the DB' do
        command.db_command
        expect(VCAP::CloudController::ServiceDashboardClient).to have_received(:release_client).with(client_id)
      end
    end
  end
end
