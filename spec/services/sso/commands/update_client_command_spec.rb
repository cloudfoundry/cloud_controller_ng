require 'spec_helper'

module VCAP::Services::SSO::Commands
  describe UpdateClientCommand do
    let(:client_attrs) do
      {
        'id' => 'client-id-1',
        'secret' => 'sekret',
        'redirect_uri' => 'https://foo.com'
      }
    end

    let(:command) do
      UpdateClientCommand.new(client_attrs)
    end

    describe '#uaa_command' do
      it 'renders the correct hash request to update in a UAA transaction' do
        expect(command.uaa_command).to eq({ action: 'update,secret' })
      end
    end
  end
end
