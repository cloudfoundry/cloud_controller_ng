require 'spec_helper'

module VCAP::CloudController
  RSpec.describe UaaClient do
    let(:url) { 'http://uaa.example.com' }
    let(:client_id) { 'client_id' }
    let(:secret) { 'secret_key' }
    let(:expected_uaa_options) { { skip_ssl_validation: false, ssl_ca_file: 'path/to/ca/file', http_timeout: TestConfig.config_instance.get(:uaa, :client_timeout) } }

    subject(:uaa_client) { UaaClient.new(uaa_target: url, client_id: client_id, secret: secret, ca_file: 'path/to/ca/file') }
    let(:auth_header) { 'bearer STUFF' }
    let(:token_info) { double(CF::UAA::TokenInfo, auth_header: auth_header, info: {}) }
    let(:token_issuer) { double(CF::UAA::TokenIssuer, client_credentials_grant: token_info) }

    before do
      UaaTokenCache.clear!
      allow(CF::UAA::TokenIssuer).to receive(:new).with(url, client_id, secret, expected_uaa_options).and_return(token_issuer)
    end

    describe 'configuration' do
      it 'uses default http timeout value' do
        expect(uaa_client.http_timeout).to eq(TestConfig.config_instance.get(:uaa, :client_timeout))
      end

      context 'when no CA file is provided' do
        subject(:uaa_client) { UaaClient.new(uaa_target: url, client_id: client_id, secret: secret, ca_file: nil) }

        it 'constructs without issue' do
          expect(uaa_client).not_to eq(nil)
          expect(uaa_client.uaa_target).to eq(url)
          expect(uaa_client.client_id).to eq(client_id)
          expect(uaa_client.secret).to eq(secret)
          expect(uaa_client.ca_file).to eq(nil)
        end
      end
    end

    describe '#auth_header' do
      before do
        Timecop.freeze
      end

      after do
        Timecop.return
      end

      let(:token_info) { double(CF::UAA::TokenInfo, auth_header: auth_header, info: { 'expires_in' => 2400 }) }

      it 'returns the token_info\'s auth_header' do
        expect(uaa_client.auth_header).to eq 'bearer STUFF'
      end

      it 'fetches a new token after the cached token expires' do
        expect(uaa_client.auth_header).to eq 'bearer STUFF'
        Timecop.travel(2399.seconds.from_now)
        allow(token_info).to receive(:auth_header).and_return('bearer OTHERTOKEN')
        expect(uaa_client.auth_header).to eq 'bearer STUFF'
        Timecop.travel(2.seconds.from_now)
        expect(uaa_client.auth_header).to eq 'bearer OTHERTOKEN'
      end
    end

    describe '#scim' do
      it 'knows how to build a valid scim' do
        scim = uaa_client.send(:scim)
        expect(scim).to be_a(CF::UAA::Scim)
        expect(scim.instance_variable_get(:@target)).to eq(url)
        expect(scim.instance_variable_get(:@auth_header)).to eq(auth_header)
      end

      it 'gives the scim a timeout from the config uaa client_timeout' do
        scim = uaa_client.send(:scim)
        expect(scim.instance_variable_get(:@http_timeout)).to eq(60)
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

      context 'when the cached token is invalid' do
        before do
          UaaTokenCache.set_token(client_id, 'bearer invalid')

          WebMock::API.stub_request(:get, "#{url}/oauth/clients/client_id").
            with(headers: { 'Authorization' => 'bearer STUFF' }).
            to_return(
              status: 200,
              headers: { 'content-type' => 'application/json' },
              body: { 'client_id' => client_id, name: 'My Client Name' }.to_json)

          WebMock::API.stub_request(:get, "#{url}/oauth/clients/client_id").
            with(headers: { 'Authorization' => 'bearer invalid' }).
            to_return(
              status: 403,
              headers: { 'content-type' => 'application/json' },
              body: { 'error' => 'invalid_token' }.to_json)
        end

        it 'successfully refreshes the token' do
          expect(uaa_client.get_clients([client_id])).to eq([{ 'client_id' => 'client_id', 'id' => 'client_id', 'name' => 'My Client Name' }])
        end
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
          'schemas' => ['urn:scim:schemas:core:1.0'],
          'startindex' => 1,
          'itemsperpage' => 100,
          'totalresults' => 2 }

        WebMock::API.stub_request(:get, "#{url}/ids/Users").
          with(query: { 'filter' => 'id eq "111" or id eq "222"', 'count' => 2 }).
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

      context 'with invalid tokens' do
        before do
          UaaTokenCache.set_token(client_id, 'bearer invalid')

          response_body = {
            'resources' => [
              { 'id' => '111', 'origin' => 'uaa', 'username' => 'user_1' },
              { 'id' => '222', 'origin' => 'uaa', 'username' => 'user_2' }
            ],
            'schemas' => ['urn:scim:schemas:core:1.0'],
            'startindex' => 1,
            'itemsperpage' => 100,
            'totalresults' => 2 }

          WebMock::API.stub_request(:get, "#{url}/ids/Users").
            with(query: { 'filter' => 'id eq "111" or id eq "222"', 'count' => 2 }, headers: { 'Authorization' => 'bearer STUFF' }).
            to_return(
              status: 200,
              headers: { 'content-type' => 'application/json' },
              body: response_body.to_json)

          WebMock::API.stub_request(:get, "#{url}/ids/Users").
            with(query: { 'filter' => 'id eq "111" or id eq "222"', 'count' => 2 }, headers: { 'Authorization' => 'bearer invalid' }).
            to_return(
              status: 403,
              headers: { 'content-type' => 'application/json' },
              body: { 'error' => 'invalid_token' }.to_json)
        end

        context 'when token is invalid or expired one time' do
          it 'retries once and then succeeds' do
            mapping = uaa_client.usernames_for_ids([userid_1, userid_2])
            expect(mapping[userid_1]).to eq('user_1')
            expect(mapping[userid_2]).to eq('user_2')
          end
        end

        context 'when token is invalid or expired twice' do
          let(:auth_header) { 'bearer invalid' }

          it 'retries once and then returns no usernames' do
            expect(uaa_client.usernames_for_ids([userid_1, userid_2])).to eq({})
          end
        end
      end
    end

    describe '#users_for_ids' do
      let(:userid_1) { '111' }
      let(:userid_2) { '222' }

      it 'returns a map of the given ids to the corresponding user objects from UAA' do
        response_body = {
          'resources' => [
            { 'id' => '111', 'origin' => 'uaa', 'username' => 'user_1' },
            { 'id' => '222', 'origin' => 'uaa', 'username' => 'user_2' }
          ],
          'schemas' => ['urn:scim:schemas:core:1.0'],
          'startindex' => 1,
          'itemsperpage' => 100,
          'totalresults' => 2 }

        WebMock::API.stub_request(:get, "#{url}/ids/Users").
          with(query: { 'filter' => 'id eq "111" or id eq "222"', 'count' => 2 }).
          to_return(
            status: 200,
            headers: { 'content-type' => 'application/json' },
            body: response_body.to_json)

        mapping = uaa_client.users_for_ids([userid_1, userid_2])
        expect(mapping[userid_1]).to eq({ 'id' => '111', 'origin' => 'uaa', 'username' => 'user_1' })
        expect(mapping[userid_2]).to eq({ 'id' => '222', 'origin' => 'uaa', 'username' => 'user_2' })
      end

      it 'returns an empty hash when given no ids' do
        expect(uaa_client.users_for_ids([])).to eq({})
      end

      context 'when UAA is unavailable' do
        before do
          allow(uaa_client).to receive(:token_info).and_raise(UaaUnavailable)
        end

        it 'returns an empty hash' do
          expect(uaa_client.users_for_ids([userid_1])).to eq({})
        end
      end

      context 'when were asking for over 200 users' do
        let(:user_ids) { (0...300).to_a }
        let(:actual_users) do
          user_ids.map do |id|
            { 'id' => id.to_s, 'origin' => 'uaa', 'username' => "user_#{id}" }
          end
        end
        let(:response_body1) do
          {
            'resources' => actual_users.slice(0, 200),
            'schemas' => ['urn:scim:schemas:core:1.0'],
            'startindex' => 1,
            'itemsperpage' => 200,
            'totalresults' => 2
          }
        end
        let(:response_body2) do
          {
            'resources' => actual_users.slice(200, 200),
            'schemas' => ['urn:scim:schemas:core:1.0'],
            'startindex' => 1,
            'itemsperpage' => 100,
            'totalresults' => 2
          }
        end

        before do
          WebMock::API.stub_request(:get, "#{url}/ids/Users").
            with(query: {
            'filter' => user_ids.slice(0, 200).map { |user_id| %(id eq "#{user_id}") }.join(' or '),
            'count' => 200
          }).to_return(
            status: 200,
            headers: { 'content-type' => 'application/json' },
            body: response_body1.to_json)

          WebMock::API.stub_request(:get, "#{url}/ids/Users").
            with(query: {
            'filter' => user_ids.slice(200, 100).map { |user_id| %(id eq "#{user_id}") }.join(' or '),
            'count' => 100
          }).to_return(
            status: 200,
            headers: { 'content-type' => 'application/json' },
            body: response_body2.to_json)
        end

        it 'returns the list of users after making batch requests' do
          results = uaa_client.users_for_ids(user_ids)
          expect(results).to eq(actual_users.map { |user| [user['id'], user] }.to_h)
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
          expect(uaa_client.users_for_ids([userid_1])).to eq({})
        end

        it 'logs the error' do
          uaa_client.users_for_ids([userid_1])
          expect(mock_logger).to have_received(:error).with("Failed to retrieve users from UAA: #{uaa_error.inspect}")
        end
      end

      context 'with invalid tokens' do
        before do
          UaaTokenCache.set_token(client_id, 'bearer invalid')

          response_body = {
            'resources' => [
              { 'id' => '111', 'origin' => 'uaa', 'username' => 'user_1' },
              { 'id' => '222', 'origin' => 'uaa', 'username' => 'user_2' }
            ],
            'schemas' => ['urn:scim:schemas:core:1.0'],
            'startindex' => 1,
            'itemsperpage' => 100,
            'totalresults' => 2 }

          WebMock::API.stub_request(:get, "#{url}/ids/Users").
            with(query: { 'filter' => 'id eq "111" or id eq "222"', 'count' => 2 }, headers: { 'Authorization' => 'bearer STUFF' }).
            to_return(
              status: 200,
              headers: { 'content-type' => 'application/json' },
              body: response_body.to_json)

          WebMock::API.stub_request(:get, "#{url}/ids/Users").
            with(query: { 'filter' => 'id eq "111" or id eq "222"', 'count' => 2 }, headers: { 'Authorization' => 'bearer invalid' }).
            to_return(
              status: 403,
              headers: { 'content-type' => 'application/json' },
              body: { 'error' => 'invalid_token' }.to_json)
        end

        context 'when token is invalid or expired one time' do
          it 'retries once and then succeeds' do
            mapping = uaa_client.users_for_ids([userid_1, userid_2])
            expect(mapping[userid_1]).to eq({ 'id' => '111', 'origin' => 'uaa', 'username' => 'user_1' })
            expect(mapping[userid_2]).to eq({ 'id' => '222', 'origin' => 'uaa', 'username' => 'user_2' })
          end
        end

        context 'when token is invalid or expired twice' do
          let(:auth_header) { 'bearer invalid' }

          it 'retries once and then returns no usernames' do
            expect(uaa_client.users_for_ids([userid_1, userid_2])).to eq({})
          end
        end
      end
    end

    describe '#id_for_username' do
      let(:username) { 'user@example.com' }

      context 'with an origin is specified' do
        it 'returns the id for the username' do
          response_body = {
            'resources' => [
              { 'id' => '123', 'origin' => 'ldap', 'username' => 'user@example.com' }],
            'schemas' => ['urn:scim:schemas:core:1.0'],
            'startindex' => 1,
            'itemsperpage' => 100,
            'totalresults' => 1 }

          WebMock::API.stub_request(:get, "#{url}/ids/Users").
            with(query: { 'includeInactive' => true, 'filter' => 'origin eq "ldap" and username eq "user@example.com"' }).
            to_return(
              status: 200,
              headers: { 'content-type' => 'application/json' },
              body: response_body.to_json)

          expect(uaa_client.id_for_username(username, origin: 'ldap')).to eq('123')
        end
      end

      context 'with an origin is not specified' do
        it 'returns the id for the username' do
          response_body = {
            'resources' => [
              { 'id' => '123', 'origin' => 'uaa', 'username' => 'user@example.com' }],
            'schemas' => ['urn:scim:schemas:core:1.0'],
            'startindex' => 1,
            'itemsperpage' => 100,
            'totalresults' => 1 }

          WebMock::API.stub_request(:get, "#{url}/ids/Users").
            with(query: { 'includeInactive' => true, 'filter' => 'username eq "user@example.com"' }).
            to_return(
              status: 200,
              headers: { 'content-type' => 'application/json' },
              body: response_body.to_json)

          expect(uaa_client.id_for_username(username)).to eq('123')
        end
      end

      it 'returns nil when given username does not exist' do
        response_body = {
          'resources' => [],
          'schemas' => ['urn:scim:schemas:core:1.0'],
          'startindex' => 1,
          'itemsperpage' => 100,
          'totalresults' => 0 }

        WebMock::API.stub_request(:get, "#{url}/ids/Users").
          with(query: { 'includeInactive' => true, 'filter' => 'username eq "user@example.com"' }).
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

    describe '#ids_for_usernames_and_origins' do
      let(:username1) { 'user1@example.com' }
      let(:username2) { 'user2@example.com' }

      context 'with usernames but no origins' do
        it 'returns the ids for the usernames' do
          response_body = {
            'resources' => [
              { 'id' => '123', 'origin' => 'uaa', 'username' => username1 },
              { 'id' => '456', 'origin' => 'Okta', 'username' => username1 },
              { 'id' => '789', 'origin' => 'Okta', 'username' => username2 },
            ],
            'schemas' => ['urn:scim:schemas:core:1.0'],
            'startindex' => 1,
            'itemsperpage' => 100,
            'totalresults' => 1 }

          WebMock::API.stub_request(:get, "#{url}/ids/Users"). # 'id eq "111" or id eq "222"'
            with(query: { 'includeInactive' => true, 'filter' => "username eq \"#{username1}\" or username eq \"#{username2}\"" }).
            to_return(
              status: 200,
              headers: { 'content-type' => 'application/json' },
              body: response_body.to_json)

          expect(uaa_client.ids_for_usernames_and_origins([username1, username2], nil)).to eq(%w(123 456 789))
        end
      end

      context 'with usernames and origins' do
        it 'returns the intersection of the usernames and the origins' do
          response_body = {
            'resources' => [
              { 'id' => '456', 'origin' => 'Okta', 'username' => username1 },
              { 'id' => '789', 'origin' => 'Okta', 'username' => username2 },
            ],
            'schemas' => ['urn:scim:schemas:core:1.0'],
            'startindex' => 1,
            'itemsperpage' => 100,
            'totalresults' => 1 }

          WebMock::API.stub_request(:get, "#{url}/ids/Users"). # 'id eq "111" or id eq "222"'
            with(query: { 'includeInactive' => true, 'filter' => "( username eq \"#{username1}\" or username eq \"#{username2}\" ) and ( origin eq \"Okta\" )" }).
            to_return(
              status: 200,
              headers: { 'content-type' => 'application/json' },
              body: response_body.to_json)

          uaa_client.ids_for_usernames_and_origins([username1, username2], ['Okta'])
        end
      end

      it 'returns empty array when given usernames do not exist' do
        response_body = {
          'resources' => [],
          'schemas' => ['urn:scim:schemas:core:1.0'],
          'startindex' => 1,
          'itemsperpage' => 100,
          'totalresults' => 0 }

        WebMock::API.stub_request(:get, "#{url}/ids/Users").
          with(query: { 'includeInactive' => true, 'filter' => 'username eq "non-existent-user"' }).
          to_return(
            status: 200,
            headers: { 'content-type' => 'application/json' },
            body: response_body.to_json)

        expect(uaa_client.ids_for_usernames_and_origins(['non-existent-user'], nil)).to eq([])
      end

      context 'when UAA is unavailable' do
        before do
          allow(uaa_client).to receive(:token_info).and_raise(UaaUnavailable)
        end

        it 'raises UaaUnavailable' do
          expect {
            uaa_client.ids_for_usernames_and_origins([username1], nil)
          }.to raise_error(UaaUnavailable)
        end
      end

      context 'when the endpoint is disabled' do
        before do
          scim = double('scim')
          allow(scim).to receive(:query).and_raise(CF::UAA::TargetError)
          allow(uaa_client).to receive(:scim).and_return(scim)
        end

        it 'raises UaaEndpointDisabled' do
          expect {
            uaa_client.ids_for_usernames_and_origins([username1], nil)
          }.to raise_error(UaaEndpointDisabled)
        end
      end

      context 'when UAA is down' do
        before do
          scim = double('scim')
          allow(scim).to receive(:query).and_raise(CF::UAA::BadTarget)
          allow(uaa_client).to receive(:scim).and_return(scim)
        end

        it 'raises UaaEndpointDisabled' do
          expect {
            uaa_client.ids_for_usernames_and_origins([username1], nil)
          }.to raise_error(UaaEndpointDisabled)
        end
      end
    end

    describe '#origins_for_username' do
      let(:userid_1) { '111' }
      let(:username) { 'user_1' }
      context 'when no exception is thrown' do
        it 'gets the origins for the user' do
          response_body = {
            'resources' => [
              { 'id' => '111', 'origin' => 'larrys_origin', 'username' => username },
              { 'id' => '111', 'origin' => 'larrys_other_origin', 'username' => username }
            ],
            'schemas' => ['urn:scim:schemas:core:1.0'],
            'startindex' => 1,
            'itemsperpage' => 100,
            'totalresults' => 2 }

          WebMock::API.stub_request(:get, "#{url}/ids/Users").
            with(query: { 'includeInactive' => true, 'filter' => 'username eq "user_1"' }).
            to_return(
              status: 200,
              headers: { 'content-type' => 'application/json' },
              body: response_body.to_json)

          origins = uaa_client.origins_for_username(username)
          expect(origins).to contain_exactly('larrys_origin', 'larrys_other_origin')
        end
      end

      it 'returns an empty array when the username is not in any origin' do
        response_body = {
          'resources' => [],
          'schemas' => ['urn:scim:schemas:core:1.0'],
          'startindex' => 1,
          'itemsperpage' => 100,
          'totalresults' => 0 }

        WebMock::API.stub_request(:get, "#{url}/ids/Users").
          with(query: { 'includeInactive' => true, 'filter' => 'username eq "user_1"' }).
          to_return(
            status: 200,
            headers: { 'content-type' => 'application/json' },
            body: response_body.to_json)

        origins = uaa_client.origins_for_username('user_1')
        expect(origins.size).to eq(0)
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

      context 'when the endpoint returns an error' do
        let(:uaa_error) { CF::UAA::UAAError.new('some error') }
        let(:mock_logger) { double(:steno_logger, error: nil) }

        before do
          scim = instance_double(CF::UAA::Scim)
          allow(scim).to receive(:query).and_raise(uaa_error)
          allow(uaa_client).to receive(:scim).and_return(scim)
          allow(uaa_client).to receive(:logger).and_return(mock_logger)
        end

        it 'raises an exception' do
          expect {
            uaa_client.origins_for_username(username)
          }.to raise_error(UaaUnavailable)
          expect(mock_logger).to have_received(:error).with("Failed to retrieve origins from UAA: #{uaa_error.inspect}")
        end
      end
    end
  end
end
