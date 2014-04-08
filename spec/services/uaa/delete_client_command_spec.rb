require 'spec_helper'

module VCAP::Services::UAA
  describe DeleteClientCommand do
    let(:client_id) { 'client-id-1' }

    let(:command) { DeleteClientCommand.new(client_id) }

    before do
      allow(VCAP::CloudController::ServiceDashboardClient).to receive(:remove_claim_on_client)
    end

    describe 'creating' do
      subject { command }

      its(:client_id) { should == 'client-id-1' }
      its(:client_attrs) { should == { 'id' => 'client-id-1' } }
    end

    describe '#db_command' do
      it 'unclaims the client in the DB' do
        command.db_command
        expect(VCAP::CloudController::ServiceDashboardClient).to have_received(:remove_claim_on_client).
                                                                     with('client-id-1')
      end
    end

    describe '#uaa_command' do
      it 'renders the correct hash request to delete in a UAA transaction' do
        uaa_command = command.uaa_command

        expect(uaa_command).to eq({action: 'delete'})
      end
    end
  end
end
