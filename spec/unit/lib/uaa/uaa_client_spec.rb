require 'spec_helper'

module VCAP::CloudController
  RSpec.describe UaaClient do
    let(:url) { 'http://uaa.example.com' }
    let(:client_id) { 'client_id' }
    let(:secret) { 'secret_key' }
    let(:uaa_options) { { skip_ssl_validation: false, ssl_ca_file: 'path/to/ca/file' } }

    subject(:uaa_client) { UaaClient.new(uaa_target: url, client_id: client_id, secret: secret, ca_file: 'path/to/ca/file') }
    let(:auth_header) { 'bearer STUFF' }
    let(:token_info) { double(CF::UAA::TokenInfo, auth_header: auth_header) }
    let(:token_issuer) { double(CF::UAA::TokenIssuer, client_credentials_grant: token_info) }

    before do
      allow(CF::UAA::TokenIssuer).to receive(:new).with(url, client_id, secret, uaa_options).and_return(token_issuer)
    end

    describe '#scim' do
      it 'knows how to build a valid scim' do
        scim = uaa_client.scim
        expect(scim).to be_a(CF::UAA::Scim)
        expect(scim.instance_variable_get(:@target)).to eq(url)
        expect(scim.instance_variable_get(:@auth_header)).to eq(auth_header)
      end

      it 'caches the scim' do
        expect(uaa_client.scim).to be(uaa_client.scim)
      end
    end

    describe '#token_info' do
      context 'when token information can be retrieved successfully' do
        it 'returns token_info from the token_issuer' do
          expect(uaa_client.token_info).to eq(token_info)
        end
      end

      context 'when a CF::UAA::NotFound error occurs' do
        before do
          allow(token_issuer).to receive(:client_credentials_grant).and_raise(CF::UAA::NotFound)
        end

        it 'raises a UaaUnavailable error' do
          expect { uaa_client.token_info }.to raise_error(UaaUnavailable)
        end
      end

      context 'when a CF::UAA::BadTarget error occurs' do
        before do
          allow(token_issuer).to receive(:client_credentials_grant).and_raise(CF::UAA::BadTarget)
        end

        it 'raises a UaaUnavailable error' do
          expect { uaa_client.token_info }.to raise_error(UaaUnavailable)
        end
      end

      context 'when a CF::UAA::BadResponse error occurs' do
        before do
          allow(token_issuer).to receive(:client_credentials_grant).and_raise(CF::UAA::BadResponse)
        end

        it 'raises a UaaUnavailable error' do
          expect { uaa_client.token_info }.to raise_error(UaaUnavailable)
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

    describe '#usernames_for_ids' do
      let(:userid_1) { '111' }
      let(:userid_2) { '222' }

      it 'returns a map of the given ids to the corresponding usernames from UAA' do
        response_body = {
          'resources' => [
            { 'id' => '111', 'origin' => 'uaa', 'username' => 'user_1' },
            { 'id' => '222', 'origin' => 'uaa', 'username' => 'user_2' }
          ],
          'schemas'      => ['urn:scim:schemas:core:1.0'],
          'startindex'   => 1,
          'itemsperpage' => 100,
          'totalresults' => 2 }

        WebMock::API.stub_request(:get, "#{url}/ids/Users").
          with(query: { 'filter' => 'id eq "111" or id eq "222"' }).
          to_return(
            status: 200,
            headers: { 'content-type' => 'application/json' },
            body: response_body.to_json)

        mapping = uaa_client.usernames_for_ids([userid_1, userid_2])
        expect(mapping[userid_1]).to eq('user_1')
        expect(mapping[userid_2]).to eq('user_2')
      end

      it 'returns an empty hash when given no ids' do
        expect(uaa_client.usernames_for_ids([])).to eq({})
      end

      context 'when UAA is unavailable' do
        before do
          allow(uaa_client).to receive(:token_info).and_raise(UaaUnavailable)
        end

        it 'returns an empty hash' do
          expect(uaa_client.usernames_for_ids([userid_1])).to eq({})
        end
      end

      context 'when the endpoint returns an error' do
        let(:uaa_error) { CF::UAA::UAAError.new('some error') }
        let(:mock_logger) { double(:steno_logger, error: nil) }

        before do
          scim = instance_double(CF::UAA::Scim)
          allow(scim).to receive(:query).and_raise(uaa_error)
          allow(uaa_client).to receive(:scim).and_return(scim)
          allow(uaa_client).to receive(:logger).and_return(mock_logger)
        end

        it 'returns an empty hash' do
          expect(uaa_client.usernames_for_ids([userid_1])).to eq({})
        end

        it 'logs the error' do
          uaa_client.usernames_for_ids([userid_1])
          expect(mock_logger).to have_received(:error).with("Failed to retrieve usernames from UAA: #{uaa_error.inspect}")
        end
      end
    end

    describe '#id_for_username' do
      let(:username) { 'user@example.com' }

      it 'returns the id for the username' do
        response_body = {
          'resources' => [
            { 'id' => '123', 'origin' => 'uaa', 'username' => 'user@example.com' }],
          'schemas' => ['urn:scim:schemas:core:1.0'],
          'startindex' => 1,
          'itemsperpage' => 100,
          'totalresults' => 1 }

        WebMock::API.stub_request(:get, "#{url}/ids/Users").
          with(query: { 'filter' => 'username eq "user@example.com"' }).
          to_return(
            status: 200,
            headers: { 'content-type' => 'application/json' },
            body: response_body.to_json)

        expect(uaa_client.id_for_username(username)).to eq('123')
      end

      it 'returns nil when given username does not exist' do
        response_body = {
          'resources' => [],
          'schemas' => ['urn:scim:schemas:core:1.0'],
          'startindex' => 1,
          'itemsperpage' => 100,
          'totalresults' => 0 }

        WebMock::API.stub_request(:get, "#{url}/ids/Users").
          with(query: { 'filter' => 'username eq "user@example.com"' }).
          to_return(
            status: 200,
            headers: { 'content-type' => 'application/json' },
            body: response_body.to_json)

        expect(uaa_client.id_for_username(username)).to be_nil
      end

      context 'when UAA is unavailable' do
        before do
          allow(uaa_client).to receive(:token_info).and_raise(UaaUnavailable)
        end

        it 'raises UaaUnavailable' do
          expect {
            uaa_client.id_for_username(username)
          }.to raise_error(UaaUnavailable)
        end
      end

      context 'when the endpoint is disabled' do
        before do
          scim = double('scim')
          allow(scim).to receive(:query).and_raise(CF::UAA::TargetError)
          allow(uaa_client).to receive(:scim).and_return(scim)
        end

        it 'raises UaaUnavailable' do
          expect {
            uaa_client.id_for_username(username)
          }.to raise_error(UaaEndpointDisabled)
        end
      end
    end
  end
end
