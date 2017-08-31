require 'spec_helper'

module VCAP::Services::SSO::UAA
  RSpec.describe UaaClientManager do
    let(:dashboard_client_hash) do
      {
        'id'           => 'client-id',
        'secret'       => 'client-secret',
        'redirect_uri' => 'http://redirect.com'
      }
    end

    describe '#modify_transaction' do
      let(:uaa_uri) { VCAP::CloudController::Config.config.get(:uaa, :internal_url) }
      let(:tx_url) { uaa_uri + '/oauth/clients/tx/modify' }
      let(:auth_header) { 'bearer ACCESSTOKENSTUFF' }
      let(:token_info) { double('info', auth_header: auth_header) }
      let(:token_issuer) { double('issuer', client_credentials_grant: token_info) }

      before do
        stub_request(:post, tx_url)

        opts = { skip_ssl_validation: false, ssl_ca_file: 'spec/fixtures/certs/uaa_ca.crt' }
        allow(CF::UAA::TokenIssuer).to receive(:new).with(uaa_uri, 'cc-service-dashboards', 'some-sekret', opts).
          and_return(token_issuer)
      end

      it 'makes a batch request to UAA with all changes in the changeset' do
        changeset = [
          double('create_command', uaa_command: { action: 'add' }, client_attrs: {}),
          double('update_command', uaa_command: { action: 'update' }, client_attrs: {}),
          VCAP::Services::SSO::Commands::DeleteClientCommand.new('delete-this-client')
        ]

        expected_json_body = [
          {
            client_id:              nil,
            client_secret:          nil,
            redirect_uri:           nil,
            scope:                  ['openid', 'cloud_controller_service_permissions.read'],
            authorities:            ['uaa.resource'],
            authorized_grant_types: ['authorization_code'],
            action:                 'add'
          },
          {
            client_id:              nil,
            client_secret:          nil,
            redirect_uri:           nil,
            scope:                  ['openid', 'cloud_controller_service_permissions.read'],
            authorities:            ['uaa.resource'],
            authorized_grant_types: ['authorization_code'],
            action:                 'update' },
          {
            client_id:              'delete-this-client',
            client_secret:          nil,
            redirect_uri:           nil,
            scope:                  ['openid', 'cloud_controller_service_permissions.read'],
            authorities:            ['uaa.resource'],
            authorized_grant_types: ['authorization_code'],
            action:                 'delete'
          }
        ].to_json

        client_manager = UaaClientManager.new
        client_manager.modify_transaction(changeset)

        expect(a_request(:post, tx_url).with(
                 body:    expected_json_body,
                 headers: { 'Authorization' => auth_header })).to have_been_made
      end

      it 'logs a sanitized version of the request' do
        changeset = [
          double('update_command', uaa_command: { client_id: 'id', client_secret: 'secret' }, client_attrs: {}),
        ]

        logger = double('logger')
        allow(Steno).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)

        expect(logger).to receive(:info) do |arg|
          expect(arg).to match /POST UAA transaction: #{tx_url}/
          expect(arg).to_not match /client_secret/
        end

        client_manager = UaaClientManager.new
        client_manager.modify_transaction(changeset)
      end

      context 'when the changeset is empty' do
        it 'does not make any http requests' do
          client_manager = UaaClientManager.new
          client_manager.modify_transaction([])

          expect(a_request(:post, tx_url)).not_to have_been_made
        end
      end

      context 'when the UAA transaction returns a 404' do
        before do
          stub_request(:post, tx_url).to_return(status: 404)
        end

        it 'raises a UaaResourceNotFound error' do
          changeset = [
            VCAP::Services::SSO::Commands::DeleteClientCommand.new('delete-this-client')
          ]

          client_manager = UaaClientManager.new

          expect {
            client_manager.modify_transaction(changeset)
          }.to raise_error(VCAP::CloudController::UaaResourceNotFound)
        end
      end

      context 'when the CF router returns a 404' do
        before do
          stub_request(:post, tx_url).to_return(
            status: 404, headers: { 'X-Cf-Routererror' => 'unknown_route' })
        end

        it 'raises a UaaUnavailable error' do
          changeset = [
            VCAP::Services::SSO::Commands::DeleteClientCommand.new('delete-this-client')
          ]

          client_manager = UaaClientManager.new

          expect {
            client_manager.modify_transaction(changeset)
          }.to raise_error(VCAP::CloudController::UaaUnavailable)
        end
      end

      context 'when the UAA transaction returns a 409' do
        before do
          stub_request(:post, tx_url).to_return(status: 409)
        end

        it 'raises a UaaResourceAlreadyExists' do
          changeset = [
            VCAP::Services::SSO::Commands::DeleteClientCommand.new('delete-this-client')
          ]

          client_manager = UaaClientManager.new

          expect {
            client_manager.modify_transaction(changeset)
          }.to raise_error(VCAP::CloudController::UaaResourceAlreadyExists)
        end
      end

      context 'when the UAA transaction returns a 400' do
        before do
          stub_request(:post, tx_url).to_return(status: 400)
        end

        it 'raises a UaaResourceInvalid error' do
          changeset = [
            VCAP::Services::SSO::Commands::DeleteClientCommand.new('delete-this-client')
          ]

          client_manager = UaaClientManager.new

          expect {
            client_manager.modify_transaction(changeset)
          }.to raise_error(VCAP::CloudController::UaaResourceInvalid)
        end
      end

      context 'when the UAA transaction returns an unexpected response' do
        before do
          stub_request(:post, tx_url).to_return(status: 500)
        end

        it 'raises a UaaUnexpectedResponse' do
          changeset = [
            VCAP::Services::SSO::Commands::DeleteClientCommand.new('delete-this-client')
          ]

          client_manager = UaaClientManager.new

          expect {
            client_manager.modify_transaction(changeset)
          }.to raise_error(VCAP::CloudController::UaaUnexpectedResponse)
        end
      end

      context 'when the UAA is unavailable while requesting a token' do
        before do
          allow(token_issuer).to receive(:client_credentials_grant).and_raise(CF::UAA::NotFound)
        end

        it 'raises a UaaUnavailable error' do
          changeset = [
            VCAP::Services::SSO::Commands::DeleteClientCommand.new('delete-this-client')
          ]

          client_manager = UaaClientManager.new

          expect {
            client_manager.modify_transaction(changeset)
          }.to raise_error(VCAP::CloudController::UaaUnavailable)
        end
      end

      describe 'ssl options' do
        let(:mock_http) { instance_double(Net::HTTP) }
        let(:mock_cert_store) { instance_double(OpenSSL::X509::Store) }

        before do
          allow(Net::HTTP).to receive(:new).and_return(mock_http)
          allow(mock_http).to receive(:use_ssl=)
          allow(mock_http).to receive(:verify_mode=)
          allow(OpenSSL::X509::Store).to receive(:new).and_return(mock_cert_store)
          allow(mock_http).to receive(:ca_file=)
          allow(mock_http).to receive(:cert_store=)
          allow(mock_http).to receive(:cert_store).and_return(mock_cert_store)
          allow(mock_http).to receive(:request).and_return(double(:response, code: '200'))
          allow(mock_cert_store).to receive(:set_default_paths)
        end

        it 'sets use_ssl to true' do
          changeset = [
            double('command', uaa_command: {}, client_attrs: {}),
          ]

          client_manager = UaaClientManager.new
          client_manager.modify_transaction(changeset)

          expect(mock_http).to have_received(:use_ssl=).with(true)
          expect(mock_http).to have_received(:verify_mode=)
        end

        it 'sets verify_mode to verify_peer' do
          changeset = [
            double('command', uaa_command: {}, client_attrs: {}),
          ]

          client_manager = UaaClientManager.new
          client_manager.modify_transaction(changeset)

          expect(mock_http).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

          expect(mock_http).to have_received(:cert_store=).with(mock_cert_store)
          expect(mock_cert_store).to have_received(:set_default_paths)
        end

        it 'sets the ca_file' do
          changeset = [
            double('command', uaa_command: {}, client_attrs: {}),
          ]

          client_manager = UaaClientManager.new
          client_manager.modify_transaction(changeset)

          expect(mock_http).to have_received(:ca_file=).with('spec/fixtures/certs/uaa_ca.crt')
        end
      end

      describe 'scope options' do
        let(:changeset) { [
          double('create_command', uaa_command: { action: 'add' }, client_attrs: {})
        ]
        }
        let(:expected_json_body) { [
          {
            client_id:              nil,
            client_secret:          nil,
            redirect_uri:           nil,
            scope:                  expected_scope,
            authorities:            ['uaa.resource'],
            authorized_grant_types: ['authorization_code'],
            action:                 'add'
          }
        ].to_json
        }
        let(:client_manager) { UaaClientManager.new }

        before do
          allow(VCAP::CloudController::Config.config.config_hash).to receive(:[]).with(anything).and_call_original
          allow(VCAP::CloudController::Config.config.config_hash).to receive(:[]).with(:uaa_client_scope).and_return(configured_scope)

          client_manager.modify_transaction(changeset)
        end

        context 'and the uaa_client_scope has been configured with minimal options' do
          let(:configured_scope) { 'openid,cloud_controller_service_permissions.read' }
          let(:expected_scope) { ['openid', 'cloud_controller_service_permissions.read'] }

          it 'makes a request to UAA with minimal scope' do
            expect(a_request(:post, tx_url).with(
                     body:    expected_json_body,
                     headers: { 'Authorization' => auth_header })).to have_been_made
          end
        end

        context 'and the uaa_client_scope has been configured with extended options' do
          let(:configured_scope) { 'cloud_controller.write,openid,cloud_controller.read,cloud_controller_service_permissions.read' }
          let(:expected_scope) { ['cloud_controller.write', 'openid', 'cloud_controller.read', 'cloud_controller_service_permissions.read'] }

          it 'makes a request to UAA with extended scope' do
            expect(a_request(:post, tx_url).with(
                     body:    expected_json_body,
                     headers: { 'Authorization' => auth_header })).to have_been_made
          end
        end

        context 'and the uaa_client_scope has been configured with options not in the whitelist' do
          let(:configured_scope) { 'openid,some_other_scope,openid_another_scope' }
          let(:expected_scope) { ['openid'] }

          it 'makes a request to UAA with extended scope' do
            expect(a_request(:post, tx_url).with(
                     body:    expected_json_body,
                     headers: { 'Authorization' => auth_header })).to have_been_made
          end
        end
      end
    end
  end
end
