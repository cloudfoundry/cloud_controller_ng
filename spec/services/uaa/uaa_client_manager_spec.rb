require 'spec_helper'

module VCAP::Services::UAA
  describe UaaClientManager do
    let(:dashboard_client_hash) do
      {
        'id' => 'client-id',
        'secret' => 'client-secret',
        'redirect_uri' => 'http://redirect.com'
      }
    end
    let(:scim) { double('scim') }

    describe '#create' do
      it 'creates a new uaa client with the given id, secret, and redirect uri' do
        scim.stub(:add)
        client_manager = UaaClientManager.new(scim: scim)

        client_manager.create(dashboard_client_hash)

        expect(scim).to have_received(:add).with(
          :client,
          hash_including(client_id: 'client-id', client_secret: 'client-secret', redirect_uri: 'http://redirect.com')
        )
      end

      context 'when no uaa client is specified in the configuration' do
        before do
          VCAP::CloudController::Config.config.stub(:[]).with(:uaa_client_name).and_return(nil)
          VCAP::CloudController::Config.config.stub(:[]).with(:uaa_client_secret).and_return(nil)
        end

        it 'does not create a new uaa client' do
          scim.stub(:add)
          client_manager = UaaClientManager.new(scim: scim)

          client_manager.create(dashboard_client_hash)

          expect(scim).not_to have_received(:add)
        end
      end

      context 'when adding the client raises an error' do
        let(:error) { CF::UAA::TargetError.new('my error') }

        before do
          allow(scim).to receive(:add).and_raise(error)
        end

        it 're-raises the same error' do
          expect {
            UaaClientManager.new(scim: scim).create(dashboard_client_hash)
          }.to raise_error(error)
        end
      end
    end

    describe '#update' do
      let(:updated_dashboard_client_hash) do
        {
          'id' => 'client-id',
          'secret' => 'updated-client-secret',
          'redirect_uri' => 'http://redirect.updated.com'
        }
      end

      before do
        allow(scim).to receive(:delete)
        allow(scim).to receive(:add)
      end

      it 'updates the client' do
        client_manager = UaaClientManager.new(scim: scim)

        client_manager.update(updated_dashboard_client_hash)

        expect(scim).to have_received(:delete).with(:client, 'client-id')
        expect(scim).to have_received(:add).with(:client,
          hash_including(client_id: 'client-id',
                         client_secret: 'updated-client-secret',
                         redirect_uri: 'http://redirect.updated.com'))
      end
    end

    describe '#delete' do
      it 'deletes the uaa client' do
        scim.stub(:delete)
        client_manager = UaaClientManager.new(scim: scim)

        client_manager.delete(dashboard_client_hash['id'])

        expect(scim).to have_received(:delete).with(:client, 'client-id')
      end

      it 'does not raise an error if the request returns a 404' do
        scim.stub(:delete).and_raise(CF::UAA::NotFound)
        client_manager = UaaClientManager.new(scim: scim)

        expect{ client_manager.delete('client-id') }.not_to raise_error
      end
    end

    describe 'building a scim' do
      it 'knows how to build a valid scim' do
        creator = UaaClientManager.new
        token_info = double('info', auth_header: 'bearer BLAH')
        token_issuer = double('issuer', client_credentials_grant: token_info)

        CF::UAA::TokenIssuer.stub(:new).with('http://localhost:8080/uaa', 'cc_service_broker_client', 'some-sekret').and_return(token_issuer)

        expect(creator.send(:scim)).to be_a(CF::UAA::Scim)
        expect(token_issuer).to have_received(:client_credentials_grant)
      end
    end

    describe '#get_clients' do
      it 'returns the clients that are in uaa' do
        allow(scim).to receive(:get).and_return({ 'client_id' => 'existing-id' })
        client_manager = UaaClientManager.new(scim: scim)

        result = client_manager.get_clients(['existing-id'])

        expect(scim).to have_received(:get).with(:client, 'existing-id').once
        expect(result).to be_a(Array)
        expect(result.length).to eq(1)
        expect(result[0]).to include('client_id' => 'existing-id')
      end

      it 'does not return clients that are not in uaa' do
        allow(scim).to receive(:get).with(:client, 'existing-id').and_return({ 'client_id' => 'existing-id' })
        allow(scim).to receive(:get).with(:client, 'non-existing-id').and_raise(CF::UAA::NotFound.new)
        client_manager = UaaClientManager.new(scim: scim)

        result = client_manager.get_clients(['existing-id', 'non-existing-id'])

        expect(scim).to have_received(:get).with(:client, 'existing-id').once
        expect(scim).to have_received(:get).with(:client, 'non-existing-id').once
        expect(result).to be_a(Array)
        expect(result.length).to eq(1)
        expect(result[0]).to include('client_id' => 'existing-id')
      end
    end

  end
end
