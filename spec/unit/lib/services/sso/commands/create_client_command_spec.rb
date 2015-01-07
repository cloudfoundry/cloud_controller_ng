require 'spec_helper'

module VCAP::Services::SSO::Commands
  describe CreateClientCommand do
    let(:client_attrs) do
      {
        'id' => 'client-id-1',
        'secret' => 'sekret',
        'redirect_uri' => 'https://foo.com'
      }
    end

    let(:command) do
      CreateClientCommand.new(client_attrs)
    end

    describe '#uaa_command' do
      it 'renders the correct hash request to create in a UAA transaction' do
        uaa_command = command.uaa_command
        expect(uaa_command).to eq({ action: 'add' })
      end
    end
  end
end
