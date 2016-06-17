require 'spec_helper'

module VCAP::Services::SSO::Commands
  RSpec.describe DeleteClientCommand do
    let(:client_id) { 'client-id-1' }

    let(:command) { DeleteClientCommand.new(client_id) }

    describe '#uaa_command' do
      it 'renders the correct hash request to delete in a UAA transaction' do
        uaa_command = command.uaa_command

        expect(uaa_command).to eq({ action: 'delete' })
      end
    end
  end
end
