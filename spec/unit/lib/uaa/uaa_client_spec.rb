require 'spec_helper'

module VCAP::CloudController
  describe UaaClient do
    let(:url) { 'http://uaa.example.com' }
    let(:client_id) { 'client_id' }
    let(:secret) { 'secret_key' }
    let(:uaa_options) { { skip_ssl_validation: false } }

    let(:uaa_client) { UaaClient.new(url, client_id, secret) }
    let(:auth_header) { 'bearer STUFF' }
    let(:token_info) { double(CF::UAA::TokenInfo, auth_header: auth_header) }
    let(:token_issuer) { double(CF::UAA::TokenIssuer, client_credentials_grant: token_info) }

    describe 'scim' do
      before do
        allow(CF::UAA::TokenIssuer).to receive(:new).with(url, client_id, secret, uaa_options).and_return(token_issuer)
      end

      it 'knows how to build a valid scim' do
        scim = uaa_client.scim
        expect(scim).to be_a(CF::UAA::Scim)
        expect(scim.instance_variable_get(:@target)).to eq(url)
        expect(scim.instance_variable_get(:@auth_header)).to eq(auth_header)
      end

      it 'caches the scim' do
        expect(uaa_client.scim).to be(uaa_client.scim)
      end

      context 'when skip_ssl_validation is true' do
        let(:uaa_options) { { skip_ssl_validation: true } }
        let(:uaa_client) { UaaClient.new(url, client_id, secret, uaa_options) }

        it 'skips ssl validation for TokenIssuer and Scim creation' do
          scim = uaa_client.scim
          expect(scim.instance_variable_get(:@skip_ssl_validation)).to eq(true)
        end
      end
    end

    describe '#get_clients' do
      let(:scim) { double('scim') }

      it 'returns the clients that are in uaa' do
        allow(scim).to receive(:get).and_return({ 'client_id' => 'existing-id' })
        allow(uaa_client).to receive(:scim).and_return(scim)
        result = uaa_client.get_clients(['existing-id'])

        expect(scim).to have_received(:get).with(:client, 'existing-id').once
        expect(result).to be_a(Array)
        expect(result.length).to eq(1)
        expect(result[0]).to include('client_id' => 'existing-id')
      end

      it 'does not return clients that are not in uaa' do
        allow(scim).to receive(:get).with(:client, 'existing-id').and_return({ 'client_id' => 'existing-id' })
        allow(scim).to receive(:get).with(:client, 'non-existing-id').and_raise(CF::UAA::NotFound.new)
        allow(uaa_client).to receive(:scim).and_return(scim)
        result = uaa_client.get_clients(['existing-id', 'non-existing-id'])

        expect(scim).to have_received(:get).with(:client, 'existing-id').once
        expect(scim).to have_received(:get).with(:client, 'non-existing-id').once
        expect(result).to be_a(Array)
        expect(result.length).to eq(1)
        expect(result[0]).to include('client_id' => 'existing-id')
      end
    end
  end
end
