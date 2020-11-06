require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'v3 service credential bindings' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:other_space) { VCAP::CloudController::Space.make }
  let(:space_dev_headers) do
    org.add_user(user)
    space.add_developer(user)
    headers_for(user)
  end

  describe 'GET /v3/service_credential_bindings' do
    describe 'order_by' do
      it_behaves_like 'list endpoint order_by name', '/v3/service_credential_bindings' do
        let(:resource_klass) { VCAP::CloudController::ServiceBinding }
      end

      it_behaves_like 'list endpoint order_by timestamps', '/v3/service_credential_bindings' do
        let(:resource_klass) { VCAP::CloudController::ServiceBinding }
      end
    end

    context 'given a mixture of bindings' do
      let(:now) { Time.now }
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
      let(:other_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: other_space) }
      let!(:key_binding) { VCAP::CloudController::ServiceKey.make(service_instance: instance, created_at: now - 4.seconds) }
      let!(:other_key_binding) { VCAP::CloudController::ServiceKey.make(service_instance: other_instance, created_at: now - 3.seconds) }
      let!(:app_binding) do
        VCAP::CloudController::ServiceBinding.make(service_instance: instance, created_at: now - 2.seconds).tap do |binding|
          operate_on(binding)
        end
      end
      let!(:other_app_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: other_instance, created_at: now - 1.second, name: Sham.name) }

      describe 'permissions' do
        let(:api_call) { ->(user_headers) { get '/v3/service_credential_bindings?order_by=created_at', nil, user_headers } }

        let(:all_bindings) do
          {
            code: 200,
            response_objects: [
              expected_json(key_binding),
              expected_json(other_key_binding),
              expected_json(app_binding),
              expected_json(other_app_binding),
            ]
          }
        end

        let(:space_bindings) do
          {
            code: 200,
            response_objects: [
              expected_json(key_binding),
              expected_json(app_binding)
            ]
          }
        end

        let(:expected_codes_and_responses) do
          Hash.new(
            code: 200,
            response_objects: []
          ).tap do |h|
            h['admin'] = all_bindings
            h['admin_read_only'] = all_bindings
            h['global_auditor'] = all_bindings
            h['space_developer'] = space_bindings
            h['space_manager'] = space_bindings
            h['space_auditor'] = space_bindings
            h['org_manager'] = space_bindings
          end
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
      end

      describe 'pagination' do
        let(:resources) { [key_binding, other_key_binding, app_binding, other_app_binding] }

        it_behaves_like 'paginated response', '/v3/service_credential_bindings'
      end

      describe 'filters' do
        let(:some_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
        let!(:another_key) { VCAP::CloudController::ServiceKey.make(service_instance: some_instance) }
        let!(:another_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: some_instance) }

        before do
          get '/v3/service_credential_bindings', nil, admin_headers
          expect(parsed_response['resources']).to have(6).items
        end

        describe 'service instance names' do
          it 'returns empty when there is no match' do
            get '/v3/service_credential_bindings?service_instance_names=fake-name', nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources']).to be_empty
          end

          it 'returns the filtered bindings' do
            get "/v3/service_credential_bindings?order_by=created_at&service_instance_names=#{instance.name},#{other_instance.name}", nil, admin_headers
            check_filtered_bindings(
              expected_json(key_binding),
              expected_json(other_key_binding),
              expected_json(app_binding),
              expected_json(other_app_binding)
            )
          end
        end

        describe 'service instance guids' do
          it 'returns empty when there is no match' do
            get '/v3/service_credential_bindings?service_instance_guids=fake-guid', nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources']).to be_empty
          end

          it 'returns the filtered bindings' do
            get "/v3/service_credential_bindings?order_by=created_at&service_instance_guids=#{instance.guid},#{other_instance.guid}", nil, admin_headers
            check_filtered_bindings(
              expected_json(key_binding),
              expected_json(other_key_binding),
              expected_json(app_binding),
              expected_json(other_app_binding)
            )
          end
        end

        describe 'service plan names' do
          it 'returns empty when there is no match' do
            get '/v3/service_credential_bindings?service_plan_names=fake-name', nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources']).to be_empty
          end

          it 'returns the filtered bindings' do
            filter = "service_plan_names=#{instance.service_plan.name},#{other_instance.service_plan.name}"
            get "/v3/service_credential_bindings?order_by=created_at&#{filter}", nil, admin_headers
            check_filtered_bindings(
              expected_json(key_binding),
              expected_json(other_key_binding),
              expected_json(app_binding),
              expected_json(other_app_binding)
            )
          end
        end

        describe 'service plan guids' do
          it 'returns empty when there is no match' do
            get '/v3/service_credential_bindings?service_plan_guids=fake-guid', nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources']).to be_empty
          end

          it 'returns the filtered bindings' do
            filter = "service_plan_guids=#{instance.service_plan.guid},#{other_instance.service_plan.guid}"
            get "/v3/service_credential_bindings?order_by=created_at&#{filter}", nil, admin_headers
            check_filtered_bindings(
              expected_json(key_binding),
              expected_json(other_key_binding),
              expected_json(app_binding),
              expected_json(other_app_binding)
            )
          end
        end

        describe 'service offering names' do
          it 'returns empty when there is no match' do
            get '/v3/service_credential_bindings?service_offering_names=fake-name', nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources']).to be_empty
          end

          it 'returns the filtered bindings' do
            filter = "service_offering_names=#{instance.service.name},#{other_instance.service.name}"
            get "/v3/service_credential_bindings?order_by=created_at&#{filter}", nil, admin_headers
            check_filtered_bindings(
              expected_json(key_binding),
              expected_json(other_key_binding),
              expected_json(app_binding),
              expected_json(other_app_binding)
            )
          end
        end

        describe 'service offering guids' do
          it 'returns empty when there is no match' do
            get '/v3/service_credential_bindings?service_offering_guids=fake-guid', nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources']).to be_empty
          end

          it 'returns the filtered bindings' do
            filter = "service_offering_guids=#{instance.service.guid},#{other_instance.service.guid}"
            get "/v3/service_credential_bindings?order_by=created_at&#{filter}", nil, admin_headers
            check_filtered_bindings(
              expected_json(key_binding),
              expected_json(other_key_binding),
              expected_json(app_binding),
              expected_json(other_app_binding)
            )
          end
        end

        describe 'names' do
          it 'returns empty when there is no match' do
            get '/v3/service_credential_bindings?names=fake-name', nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources']).to be_empty
          end

          it 'returns the filtered bindings' do
            get "/v3/service_credential_bindings?order_by=created_at&names=#{key_binding.name},#{other_app_binding.name}", nil, admin_headers
            check_filtered_bindings(
              expected_json(key_binding),
              expected_json(other_app_binding)
            )
          end
        end

        describe 'app names' do
          it 'returns empty when there is no match' do
            get '/v3/service_credential_bindings?app_names=fake-app-name', nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources']).to be_empty
          end

          it 'returns the filtered bindings' do
            get "/v3/service_credential_bindings?app_names=#{app_binding.app.name},#{other_app_binding.app.name}", nil, admin_headers
            check_filtered_bindings(
              expected_json(app_binding),
              expected_json(other_app_binding)
            )
          end
        end

        describe 'app guids' do
          it 'returns empty when there is no match' do
            get '/v3/service_credential_bindings?app_guids=fake-app-guid', nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources']).to be_empty
          end

          it 'returns the filtered bindings' do
            get "/v3/service_credential_bindings?app_guids=#{app_binding.app.guid},#{other_app_binding.app.guid}", nil, admin_headers
            check_filtered_bindings(
              expected_json(app_binding),
              expected_json(other_app_binding)
            )
          end
        end

        describe 'type' do
          it 'returns empty when there is no match' do
            another_key.destroy
            other_key_binding.destroy
            key_binding.destroy

            get '/v3/service_credential_bindings?type=key', nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources']).to be_empty
          end

          it 'errors for unknown type' do
            get '/v3/service_credential_bindings?type=route', nil, admin_headers
            expect(last_response).to have_status_code(400)
            expect(parsed_response['errors']).to include(include({
              'detail' => "The query parameter is invalid: Type must be one of 'app', 'key'"
            }))
          end

          it 'returns the filtered bindings' do
            get '/v3/service_credential_bindings?type=key', nil, admin_headers
            check_filtered_bindings(
              expected_json(key_binding),
              expected_json(other_key_binding),
              expected_json(another_key)
            )

            get '/v3/service_credential_bindings?type=app', nil, admin_headers
            check_filtered_bindings(
              expected_json(app_binding),
              expected_json(other_app_binding),
              expected_json(another_binding)
            )
          end
        end

        def check_filtered_bindings(*bindings)
          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].length).to be(bindings.length)
          expect({ resources: parsed_response['resources'] }).to match_json_response(
            { resources: bindings }
          )
        end
      end

      describe 'unknown filter' do
        let(:valid_query_params) do
          %w(
            page per_page order_by created_ats updated_ats guids names service_instance_guids service_instance_names
            service_plan_names service_plan_guids service_offering_names service_offering_guids app_guids app_names
            include type
          )
        end

        it 'returns an error' do
          get '/v3/service_credential_bindings?fruits=avocado,guava', nil, admin_headers
          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors']).to include(include({
            'detail' => "The query parameter is invalid: Unknown query parameter(s): 'fruits'. Valid parameters are: '#{valid_query_params.join("', '")}'",
            'title' => 'CF-BadQueryParameter',
            'code' => 10005,
          }))
        end
      end

      describe 'include' do
        it 'can include `app`' do
          get '/v3/service_credential_bindings?include=app', nil, admin_headers
          expect(last_response).to have_status_code(200)

          expect(parsed_response['included']['apps']).to have(2).items
          guids = parsed_response['included']['apps'].map { |x| x['guid'] }
          expect(guids).to contain_exactly(app_binding.app.guid, other_app_binding.app.guid)
        end

        it 'can include `service_instance`' do
          get '/v3/service_credential_bindings?include=service_instance', nil, admin_headers
          expect(last_response).to have_status_code(200)

          expect(parsed_response['included']['service_instances']).to have(2).items
          guids = parsed_response['included']['service_instances'].map { |x| x['guid'] }
          expect(guids).to contain_exactly(instance.guid, other_instance.guid)
        end

        it 'returns a 400 for invalid includes' do
          get '/v3/service_credential_bindings?include=routes', nil, admin_headers
          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors']).to include(include({
            'detail' => include("Invalid included resource: 'routes'"),
            'title' => 'CF-BadQueryParameter',
            'code' => 10005,
          }))
        end
      end
    end
  end

  describe 'GET /v3/service_credential_bindings/:guid' do
    describe 'query params' do
      let(:binding) { VCAP::CloudController::ServiceBinding.make }
      it 'returns 400 for invalid query params' do
        get "/v3/service_credential_bindings/#{binding.guid}?bahamas=yes-please", nil, admin_headers

        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(include({
          'detail' => "The query parameter is invalid: Unknown query parameter(s): 'bahamas'. Valid parameters are: 'include'",
          'title' => 'CF-BadQueryParameter',
          'code' => 10005,
        }))
      end

      describe 'includes' do
        it 'returns 400 for invalid includes' do
          get "/v3/service_credential_bindings/#{binding.guid}?include=routes", nil, admin_headers

          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors']).to include(include({
            'detail' => include("Invalid included resource: 'routes'"),
            'title' => 'CF-BadQueryParameter',
            'code' => 10005,
          }))
        end
      end
    end

    describe 'missing binding' do
      let(:api_call) { ->(user_headers) { get '/v3/service_credential_bindings/no-binding', nil, user_headers } }

      let(:expected_codes_and_responses) do
        Hash.new(code: 404)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    describe 'key credential binding' do
      let(:key) { VCAP::CloudController::ServiceKey.make(service_instance: instance) }
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
      let(:api_call) { ->(user_headers) { get "/v3/service_credential_bindings/#{key.guid}", nil, user_headers } }
      let(:expected_object) { expected_json(key) }

      describe 'permissions' do
        let(:expected_codes_and_responses) do
          responses_for_space_restricted_single_endpoint(expected_object)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      describe 'query params' do
        describe 'include' do
          it 'can include `app`' do
            get "/v3/service_credential_bindings/#{key.guid}?include=app", nil, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response['included']['apps']).to have(0).items
          end

          it 'can include `service_instance`' do
            get "/v3/service_credential_bindings/#{key.guid}?include=service_instance", nil, admin_headers
            expect(last_response).to have_status_code(200)

            expect(parsed_response['included']['service_instances']).to have(1).items
            guids = parsed_response['included']['service_instances'].map { |x| x['guid'] }
            expect(guids).to contain_exactly(instance.guid)
          end
        end
      end
    end

    describe 'app credential binding ' do
      let(:app_to_bind_to) { VCAP::CloudController::AppModel.make(space: space) }
      let(:app_binding) do
        VCAP::CloudController::ServiceBinding.make(service_instance: instance, app: app_to_bind_to).tap do |binding|
          operate_on(binding)
        end
      end
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
      let(:api_call) { ->(user_headers) { get "/v3/service_credential_bindings/#{app_binding.guid}", nil, user_headers } }
      let(:expected_object) { expected_json(app_binding) }

      describe 'permissions' do
        let(:expected_codes_and_responses) do
          responses_for_space_restricted_single_endpoint(expected_object)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      describe 'include' do
        it 'can include `app`' do
          get "/v3/service_credential_bindings/#{app_binding.guid}?include=app", nil, admin_headers
          expect(last_response).to have_status_code(200)

          expect(parsed_response['included']['apps']).to have(1).items
          guids = parsed_response['included']['apps'].map { |x| x['guid'] }
          expect(guids).to contain_exactly(app_to_bind_to.guid)
        end

        it 'can include `service_instance`' do
          get "/v3/service_credential_bindings/#{app_binding.guid}?include=service_instance", nil, admin_headers
          expect(last_response).to have_status_code(200)

          expect(parsed_response['included']['service_instances']).to have(1).items
          guids = parsed_response['included']['service_instances'].map { |x| x['guid'] }
          expect(guids).to contain_exactly(instance.guid)
        end
      end
    end
  end

  describe 'GET /v3/service_credential_bindings/:binding_guid/details' do
    let(:details) {
      {
        service_instance: instance,
        volume_mounts: ['foo', 'bar'],
        syslog_drain_url: 'some-drain-url',
        credentials: { 'cred_key' => 'creds-val-64', 'magic' => true }
      }
    }
    let(:app_binding) { VCAP::CloudController::ServiceBinding.make(**details) }
    let(:guid) { app_binding.guid }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:api_call) { ->(user_headers) { get "/v3/service_credential_bindings/#{guid}/details", nil, user_headers } }
    let(:binding_credentials) {
      {
        credentials: {
          cred_key: 'creds-val-64',
          magic: true
        },
        syslog_drain_url: 'some-drain-url',
        volume_mounts: ['foo', 'bar']
      }
    }

    context 'permissions' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) do
          Hash.new(code: 404).tap do |h|
            h['space_developer'] = { code: 200, response_object: binding_credentials }
            h['admin'] = { code: 200, response_object: binding_credentials }
            h['admin_read_only'] = { code: 200, response_object: binding_credentials }
          end
        end
      end

      describe 'when the service instance is shared' do
        let(:originating_space) { VCAP::CloudController::Space.make }
        let(:shared_space) { space }
        let(:user_in_shared_space) {
          u = VCAP::CloudController::User.make
          shared_space.organization.add_user(u)
          shared_space.add_developer(u)
          u
        }
        let(:user_in_originating_space) do
          u = VCAP::CloudController::User.make
          originating_space.organization.add_user(u)
          originating_space.add_developer(u)
          u
        end
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: originating_space) }
        let(:details) {
          {
            service_instance: instance,
            credentials: '{"password": "terces"}',
            app: source_app
          }
        }

        before do
          instance.add_shared_space(shared_space)
        end

        context 'bindings in the originating space' do
          let(:source_app) { VCAP::CloudController::AppModel.make(space: originating_space) }

          it 'should return the credentials for users in the originating space' do
            api_call.call(headers_for(user_in_originating_space))
            expect(last_response).to have_status_code(200)
          end

          it 'should return 404 for users in the shared space' do
            api_call.call(headers_for(user_in_shared_space))
            expect(last_response).to have_status_code(404)
          end
        end

        context 'bindings in the shared space' do
          let(:source_app) { VCAP::CloudController::AppModel.make(space: shared_space) }

          it 'should return 404 for users in the originating space' do
            api_call.call(headers_for(user_in_originating_space))
            expect(last_response).to have_status_code(404)
          end

          it 'should return the credentials for users in the shared space space' do
            api_call.call(headers_for(user_in_shared_space))
            expect(last_response).to have_status_code(200)
          end
        end
      end
    end

    describe 'credhub interaction' do
      let(:key_binding) { VCAP::CloudController::ServiceKey.make(:credhub_reference, service_instance: instance) }
      let(:credhub_url) { VCAP::CloudController::Config.config.get(:credhub_api, :internal_url) }
      let(:uaa_url) { VCAP::CloudController::Config.config.get(:uaa, :internal_url) }
      let(:credentials) { { 'username' => 'cinnamon', 'password' => 'roll' } }
      let(:credhub_response_status) { 200 }
      let(:credhub_response_body) { { data: [{ value: credentials }] }.to_json }
      let!(:credhub_server_stub) {
        stub_request(:get, "#{credhub_url}/api/v1/data?name=#{key_binding.credhub_reference}&current=true").
          with(headers: {
            'Authorization' => 'Bearer my-favourite-access-token',
            'Content-Type' => 'application/json'
          }).to_return(status: credhub_response_status, body: credhub_response_body)
      }

      before do
        token = { token_type: 'Bearer', access_token: 'my-favourite-access-token' }
        stub_request(:post, "#{uaa_url}/oauth/token").
          to_return(status: 200, body: token.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      context 'for key bindings with a credhub reference' do
        let(:guid) { key_binding.guid }

        it 'fetches and returns the credentials values from credhub' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(200)
          expect(credhub_server_stub).to have_been_requested
          expect(parsed_response['credentials']).to eq(credentials)
        end
      end

      context 'for key bindings without a credhub reference' do
        let(:key_binding) { VCAP::CloudController::ServiceKey.make(service_instance: instance) }
        let(:guid) { key_binding.guid }

        it 'returns the credentials as found in the datbase' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(200)
          expect(credhub_server_stub).not_to have_been_requested
          expect(parsed_response['credentials']).to eq(key_binding.credentials)
        end
      end

      context 'for app bindings with credhub references' do
        let(:details) { { service_instance: instance, credentials: { 'credhub-ref' => '/secret/super/morish' } } }

        it 'returns the credentials as found in the database' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(200)
          expect(credhub_server_stub).not_to have_been_requested
          expect(parsed_response['credentials']).to eq({ 'credhub-ref' => '/secret/super/morish' })
        end
      end

      context 'when the reference cannot be found on credhub' do
        let(:guid) { key_binding.guid }
        let(:credhub_response_status) { 404 }
        let(:credhub_response_body) { { error: 'cred does not exist' }.to_json }

        it 'returns an error' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(503)
          expect(parsed_response['errors']).to include(include({
            'detail' => 'Fetching credentials from CredHub failed; reason: cred does not exist',
            'title' => 'CF-ServiceUnavailable',
            'code' => 10015,
          }))
        end
      end

      context 'when credhub returns an error' do
        let(:guid) { key_binding.guid }
        let(:credhub_response_status) { 500 }
        let(:credhub_response_body) { nil }

        it 'returns an error' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(503)
          expect(parsed_response['errors']).to include(include({
            'detail' => 'Fetching credentials from CredHub failed; reason: Server error, status: 500',
            'title' => 'CF-ServiceUnavailable',
            'code' => 10015,
          }))
        end
      end
    end
  end

  describe 'GET /v3/service_credential_bindings/:binding_guid/parameters' do
    let(:binding_params) { { foo: 'bar', baz: 'xyzzy' }.with_indifferent_access }
    let(:app_to_bind_to) { VCAP::CloudController::AppModel.make(space: space) }
    let(:binding) { VCAP::CloudController::ServiceBinding.make(service_instance: instance, app: app_to_bind_to) }
    let(:guid) { binding.guid }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:api_call) { ->(user_headers) { get "/v3/service_credential_bindings/#{guid}/parameters", nil, user_headers } }

    context 'permissions' do
      before do
        instance.service.update(bindings_retrievable: true)
        stub_param_broker_request_for_binding(binding, binding_params)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) do
          responses_for_space_restricted_single_endpoint(binding_params)
        end
      end

      describe 'when the service instance is shared' do
        let(:originating_space) { VCAP::CloudController::Space.make }
        let(:shared_space) { space }
        let(:user_in_shared_space) {
          u = VCAP::CloudController::User.make
          shared_space.organization.add_user(u)
          shared_space.add_developer(u)
          u
        }
        let(:user_in_originating_space) do
          u = VCAP::CloudController::User.make
          originating_space.organization.add_user(u)
          originating_space.add_developer(u)
          u
        end
        let(:instance) do
          VCAP::CloudController::ManagedServiceInstance.make(space: originating_space).tap do |instance|
            instance.add_shared_space(shared_space)
          end
        end
        let(:binding) { VCAP::CloudController::ServiceBinding.make(service_instance: instance, app: source_app) }

        context 'bindings in the originating space' do
          let(:source_app) { VCAP::CloudController::AppModel.make(space: originating_space) }

          it 'should return the parameters for users in the originating space' do
            api_call.call(headers_for(user_in_originating_space))
            expect(last_response).to have_status_code(200)
          end

          it 'should return 404 for users in the shared space' do
            api_call.call(headers_for(user_in_shared_space))
            expect(last_response).to have_status_code(404)
          end
        end

        context 'bindings in the shared space' do
          let(:source_app) { VCAP::CloudController::AppModel.make(space: shared_space) }

          it 'should return 404 for users in the originating space' do
            api_call.call(headers_for(user_in_originating_space))
            expect(last_response).to have_status_code(404)
          end

          it 'should return the parameters for users in the shared space space' do
            api_call.call(headers_for(user_in_shared_space))
            expect(last_response).to have_status_code(200)
          end
        end
      end
    end

    describe 'app bindings' do
      context 'when the service does not allow bindings to be fetched' do
        before do
          instance.service.update(bindings_retrievable: false)
        end

        it 'should fail as can not be done' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(502)
        end
      end

      context 'when the service allows bindings to be fetched' do
        before do
          instance.service.update(bindings_retrievable: true)
        end

        context 'when an operation is still on going for the binding' do
          before do
            binding.save_with_new_operation({ type: 'create', state: 'in progress' })
          end

          it 'should fail as not allowed' do
            api_call.call(admin_headers)

            expect(last_response).to have_status_code(409)
          end
        end

        context 'when the broker returns params' do
          before do
            stub_param_broker_request_for_binding(binding, binding_params)
          end

          it 'returns the params in the response body' do
            api_call.call(admin_headers)

            expect(last_response).to have_status_code(200)
            expect(parsed_response).to eq(binding_params)
          end
        end
      end
    end

    describe 'key bindings' do
      let(:binding) { VCAP::CloudController::ServiceKey.make(service_instance: instance) }

      context 'when the service does not allow bindings to be fetched' do
        before do
          instance.service.update(bindings_retrievable: false)
        end

        it 'should fail as can not be done' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(502)
        end
      end

      context 'when the service allows bindings to be fetched' do
        before do
          instance.service.update(bindings_retrievable: true)
        end

        context 'when the broker returns params' do
          before do
            stub_param_broker_request_for_binding(binding, binding_params)
          end

          it 'returns the params in the response body' do
            api_call.call(admin_headers)

            expect(last_response).to have_status_code(200)
            expect(parsed_response).to eq(binding_params)
          end
        end
      end
    end
  end

  describe 'POST /v3/service_credential_bindings' do
    let(:api_call) { ->(user_headers) { post '/v3/service_credential_bindings', create_body.to_json, user_headers } }
    let(:request_extra) { {} }
    let(:app_to_bind_to) { VCAP::CloudController::AppModel.make(space: space) }
    let(:service_instance_details) {
      {
        syslog_drain_url: 'http://syslog.example.com/wow',
        credentials: { password: 'foo' }
      }
    }
    let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, **service_instance_details) }
    let(:app_guid) { app_to_bind_to.guid }
    let(:service_instance_guid) { service_instance.guid }
    let(:create_body) {
      {
        type: 'app',
        name: 'some-name',
        relationships: {
          service_instance: { data: { guid: service_instance_guid } },
          app: { data: { guid: app_guid } }
        }
      }.merge(request_extra)
    }

    RSpec.shared_examples 'validation of credential binding' do
      it 'returns 422 when type is missing' do
        create_body.delete(:type)

        api_call.call admin_headers
        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors']).to include(include({
          'detail' => include("Type must be 'app'"),
          'title' => 'CF-UnprocessableEntity',
          'code' => 10008,
        }))
      end

      it 'returns 422 when service instance relationship is not included' do
        create_body[:relationships].delete(:service_instance)
        api_call.call admin_headers
        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors']).to include(include({
          'detail' => include("Relationships Service instance can't be blank"),
          'title' => 'CF-UnprocessableEntity',
          'code' => 10008,
        }))
      end

      it 'returns 422 when the binding already exists' do
        api_call.call admin_headers
        expect(last_response.status).to eq(201).or eq(202)
        api_call.call admin_headers
        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors']).to include(include({
          'detail' => include('The app is already bound to the service instance'),
          'title' => 'CF-UnprocessableEntity',
          'code' => 10008,
        }))
      end

      context 'when the service instance does not exist' do
        let(:service_instance_guid) { 'fake-instance' }

        it 'returns a 422 when the service instance does not exist' do
          api_call.call admin_headers
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => include("The service instance could not be found: 'fake-instance'"),
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
        end
      end

      context 'when the app does not exist' do
        let(:app_guid) { 'fake-app' }

        it 'returns a 422 when the service instance does not exist' do
          api_call.call admin_headers
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => include("The app could not be found: 'fake-app'"),
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
        end
      end

      context 'when the user has no access to the related resources' do
        let(:space_user) do
          u = VCAP::CloudController::User.make
          other_space.organization.add_user(u)
          other_space.add_developer(u)
          u
        end

        let(:space_dev_headers) { headers_for(space_user) }

        context 'service instance' do
          it 'returns a 422' do
            api_call.call space_dev_headers
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(include({
              'detail' => include("The service instance could not be found: '#{service_instance_guid}'"),
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            }))
          end
        end

        context 'app' do
          let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: other_space) }

          it 'returns a 422' do
            api_call.call space_dev_headers
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(include({
              'detail' => include("The app could not be found: '#{app_guid}'"),
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            }))
          end
        end
      end

      context 'when creating an app binding without app relationship' do
        it 'returns a 422' do
          create_body[:relationships].delete(:app)

          api_call.call admin_headers
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => include("Relationships App can't be blank"),
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
        end
      end

      context 'when the service instance and the app are not in the same space' do
        let(:app_to_bind_to) { VCAP::CloudController::AppModel.make(space: other_space) }
        it 'returns a 422 error' do
          api_call.call admin_headers
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => include('The service instance and the app are in different spaces'),
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
        end
      end
    end

    context 'user-provided service' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['space_developer'] = { code: 201 }
            h['admin'] = { code: 201 }
            h['org_billing_manager'] = { code: 422 }
            h['org_auditor'] = { code: 422 }
            h['no_role'] = { code: 422 }
          end
        end
      end

      it_behaves_like 'validation of credential binding'

      describe 'a successful creation' do
        before do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(201)
          expect(parsed_response).to have_key('guid')
          @binding_guid = parsed_response['guid']
          @binding_name = parsed_response['name']
        end

        it 'creates a new service credential binding' do
          binding_response = {
            guid: @binding_guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: 'some-name',
            type: 'app',
            last_operation: {
              type: 'create',
              state: 'succeeded',
              created_at: iso8601,
              updated_at: iso8601,
              description: nil,
            },
            relationships: {
              service_instance: { data: { guid: service_instance_guid } },
              app: { data: { guid: app_guid } }
            },
            links: {
              self: {
                href: "#{link_prefix}/v3/service_credential_bindings/#{@binding_guid}"
              },
              details: {
                href: "#{link_prefix}/v3/service_credential_bindings/#{@binding_guid}/details"
              },
              service_instance: {
                href: "#{link_prefix}/v3/service_instances/#{service_instance_guid}"
              },
              app: {
                href: "#{link_prefix}/v3/apps/#{app_guid}"
              }
            }
          }
          expect(parsed_response).to match_json_response(binding_response)

          get "/v3/service_credential_bindings/#{@binding_guid}", {}, admin_headers
          expect(last_response).to have_status_code(200)
          expect(parsed_response).to match_json_response(binding_response)
        end

        it 'logs an audit event' do
          event = VCAP::CloudController::Event.find(type: 'audit.service_binding.create')
          expect(event).to be
          expect(event.actee).to eq(@binding_guid)
          expect(event.actee_name).to eq(@binding_name)
        end

        it 'sets the right details' do
          get "/v3/service_credential_bindings/#{@binding_guid}/details", {}, admin_headers
          expect(last_response).to have_status_code(200)
          expect(parsed_response).to match_json_response({
            credentials: { password: 'foo' },
            syslog_drain_url: 'http://syslog.example.com/wow'
          })
        end
      end

      context 'when attempting to create a key from a user-provided instance' do
        it 'returns a 422' do
          create_body[:type] = 'key'
          create_body[:relationships].delete(:app)

          api_call.call admin_headers
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => include("Type must be 'app'"),
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
        end
      end
    end

    context 'managed service' do
      let(:offering) { VCAP::CloudController::Service.make(bindings_retrievable: true) }
      let(:plan) { VCAP::CloudController::ServicePlan.make(service: offering) }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: plan) }
      let(:binding) { VCAP::CloudController::ServiceBinding.last }
      let(:audit) { VCAP::CloudController::Event.last }
      let(:job) { VCAP::CloudController::PollableJobModel.last }

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['space_developer'] = { code: 202 }
            h['admin'] = { code: 202 }
            h['org_billing_manager'] = { code: 422 }
            h['org_auditor'] = { code: 422 }
            h['no_role'] = { code: 422 }
          end
        end
      end

      it_behaves_like 'validation of credential binding'

      context 'managed instance specific validations' do
        it 'returns a 422 when the plan is not bindable' do
          service_instance.service_plan.update(bindable: false)

          api_call.call admin_headers
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => include('Service plan does not allow bindings'),
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
        end

        it 'returns a 422 when the plan is no longer available' do
          service_instance.service_plan.update(active: false)

          api_call.call admin_headers
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => include('Service plan is not available'),
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
        end

        it 'responds with 422 when there is an operation in progress for the service instance' do
          service_instance.save_with_new_operation({}, { type: 'guacamole', state: 'in progress' })
          api_call.call admin_headers
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => include('There is an operation in progress for the service instance'),
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
        end
      end

      describe 'a successful creation' do
        it 'creates a credential binding in the database' do
          api_call.call(admin_headers)

          expect(binding.service_instance).to eq(service_instance)
          expect(binding.app).to eq(app_to_bind_to)
          expect(binding.last_operation.state).to eq('in progress')
          expect(binding.last_operation.type).to eq('create')
        end

        it 'responds with a job resource' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(202)
          expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
          expect(job.operation).to eq('service_bindings.create')
          expect(job.resource_guid).to eq(binding.guid)
          expect(job.resource_type).to eq('service_credential_binding')

          get "/v3/jobs/#{job.guid}", nil, admin_headers
          expect(last_response).to have_status_code(200)
          expect(parsed_response['guid']).to eq(job.guid)
          binding_link = parsed_response.dig('links', 'service_credential_binding', 'href')
          expect(binding_link).to end_with("/v3/service_credential_bindings/#{binding.guid}")
        end
      end

      describe 'the pollable job' do
        let(:credentials) { { 'password' => 'special sauce' } }
        let(:broker_base_url) { service_instance.service_broker.broker_url }
        let(:broker_bind_url) { "#{broker_base_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{binding.guid}" }
        let(:broker_status_code) { 201 }
        let(:broker_response) { { credentials: credentials } }
        let(:client_body) do
          {
            context: {
              platform: 'cloudfoundry',
              organization_guid: org.guid,
              organization_name: org.name,
              space_guid: space.guid,
              space_name: space.name,
            },
            app_guid: app_to_bind_to.guid,
            service_id: service_instance.service_plan.service.unique_id,
            plan_id: service_instance.service_plan.unique_id,
            bind_resource: {
              app_guid: app_to_bind_to.guid,
              space_guid: service_instance.space.guid
            },
          }
        end

        before do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(202)

          stub_request(:put, broker_bind_url).
            with(query: { accepts_incomplete: true }).
            to_return(status: broker_status_code, body: broker_response.to_json, headers: {})
        end

        it 'sends a bind request with the right arguments to the service broker' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          expect(
            a_request(:put, broker_bind_url).
              with(
                body: client_body,
                query: { accepts_incomplete: true }
              )
          ).to have_been_made.once
        end

        context 'parameters are specified' do
          let(:request_extra) { { parameters: { foo: 'bar' } } }

          it 'sends the parameters to the broker' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(
              a_request(:put, broker_bind_url).
                with(
                  body: client_body.deep_merge(request_extra),
                  query: { accepts_incomplete: true }
                )
                ).to have_been_made.once
          end
        end

        context 'when the bind completes synchronously' do
          it 'updates the the binding' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            binding.reload
            expect(binding.credentials).to eq(credentials)
            expect(binding.last_operation.type).to eq('create')
            expect(binding.last_operation.state).to eq('succeeded')
          end

          it 'completes the job' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
          end

          it 'logs an audit event' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            event = VCAP::CloudController::Event.find(type: 'audit.service_binding.create')
            expect(event).to be
            expect(event.actee).to eq(binding.guid)
            expect(event.actee_name).to eq(binding.name)
            expect(event.data).to include({
              'request' => create_body.with_indifferent_access
            })
          end
        end

        context 'when the broker fails to bind' do
          let(:broker_status_code) { 422 }
          let(:broker_response) { { error: 'RequiresApp' } }

          it 'updates the the binding with a failure' do
            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            binding.reload
            expect(binding.last_operation.type).to eq('create')
            expect(binding.last_operation.state).to eq('failed')
          end

          it 'fails the job' do
            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
          end
        end

        context 'when the binding completes asynchronously' do
          let(:broker_status_code) { 202 }
          let(:operation) { Sham.guid }
          let(:broker_response) { { operation: operation } }
          let(:broker_binding_last_operation_url) { "#{broker_base_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{binding.guid}/last_operation" }
          let(:last_operation_status_code) { 200 }
          let(:description) { Sham.description }
          let(:state) { 'in progress' }
          let(:last_operation_body) do
            {
              description: description,
              state: state,
            }
          end

          before do
            stub_request(:get, broker_binding_last_operation_url).
              with(query: hash_including({
                operation: operation
              })).
              to_return(status: last_operation_status_code, body: last_operation_body.to_json, headers: {})
          end

          it 'polls the last operation endpoint' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(
              a_request(:get, broker_binding_last_operation_url).
                with(query: {
                  operation: operation,
                  service_id: service_instance.service_plan.service.unique_id,
                  plan_id: service_instance.service_plan.unique_id,
                })
            ).to have_been_made.once
          end

          it 'updates the binding and job' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(binding.last_operation.type).to eq('create')
            expect(binding.last_operation.state).to eq(state)
            expect(binding.last_operation.description).to eq(description)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
          end

          it 'logs an audit event' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            event = VCAP::CloudController::Event.find(type: 'audit.service_binding.start_create')
            expect(event).to be
            expect(event.actee).to eq(binding.guid)
            expect(event.data).to include({
              'request' => create_body.with_indifferent_access
            })
          end

          it 'enqueues the next fetch last operation job' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(Delayed::Job.count).to eq(1)
          end

          it 'keeps track of the broker operation' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(Delayed::Job.count).to eq(1)

            Timecop.travel(Time.now + 1.minute)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(
              a_request(:get, broker_binding_last_operation_url).
                with(query: {
                  operation: operation,
                  service_id: service_instance.service_plan.service.unique_id,
                  plan_id: service_instance.service_plan.unique_id,
                })
            ).to have_been_made.twice
          end

          context 'last operation response is 200 OK and indicates success' do
            let(:state) { 'succeeded' }
            let(:fetch_binding_status_code) { 200 }
            let(:syslog_drain_url) { 'http://syslog.example.com/wow' }
            let(:route_service_url) { 'http://route.example.com/wow' }
            let(:credentials) { { password: 'foo' } }
            let(:parameters) { { foo: 'bar', another_foo: 'another_bar' } }

            let(:fetch_binding_body) do
              {
                syslog_drain_url: syslog_drain_url,
                credentials: credentials,
                parameters: parameters
              }
            end

            before do
              stub_request(:get, broker_bind_url).
                to_return(status: fetch_binding_status_code, body: fetch_binding_body.to_json, headers: {})
            end

            it 'fetches the binding' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(
                a_request(:get, broker_bind_url)
              ).to have_been_made.once
            end

            it 'updates the binding and job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq(state)
              expect(binding.last_operation.description).to eq(description)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end

            it 'updates the binding details with the fetch binding response' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(binding.reload.syslog_drain_url).to eq(syslog_drain_url)
              expect(binding.credentials).to eq(credentials.with_indifferent_access)
            end

            context 'fetching binding fails ' do
              let(:fetch_binding_status_code) { 404 }
              let(:fetch_binding_body) {}

              it 'fails the job' do
                execute_all_jobs(expected_successes: 0, expected_failures: 1)

                expect(binding.last_operation.type).to eq('create')
                expect(binding.last_operation.state).to eq('failed')
                expect(binding.last_operation.description).to include('The service broker rejected the request. Status Code: 404 Not Found')

                expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
                expect(job.cf_api_error).not_to be_nil
                error = YAML.safe_load(job.cf_api_error)
                expect(error['errors'].first).to include({
                  'code' => 10009,
                  'title' => 'CF-UnableToPerform',
                  'detail' => 'bind could not be completed: The service broker rejected the request. Status Code: 404 Not Found, Body: null',
                })
              end
            end
          end

          it_behaves_like 'binding last operation response handling', 'create'

          context 'binding not retrievable' do
            let(:offering) { VCAP::CloudController::Service.make(bindings_retrievable: false) }

            it 'fails the job with an appropriate error' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq('failed')
              expect(binding.last_operation.description).to eq('The broker responded asynchronously but does not support fetching binding data')

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
              expect(job.cf_api_error).not_to be_nil
              error = YAML.safe_load(job.cf_api_error)
              expect(error['errors'].first).to include({
                'code' => 90001,
                'title' => 'CF-ServiceBindingInvalid',
                'detail' => 'The service binding is invalid: The broker responded asynchronously but does not support fetching binding data',
              })
            end
          end
        end

        context 'orphan mitigation' do
          it_behaves_like 'create binding orphan mitigation' do
            let(:bind_url) { broker_bind_url }
            let(:plan_id) { plan.unique_id }
            let(:offering_id) { offering.unique_id }
          end
        end
      end
    end
  end

  describe 'DELETE /v3/service_credential_bindings/:guid' do
    let(:api_call) { ->(user_headers) { delete "/v3/service_credential_bindings/#{guid}", {}, user_headers } }
    let(:guid) { binding.guid }
    let(:binding_details) {
      {
        service_instance: service_instance,
        app: bound_app
      }
    }
    let(:service_instance_details) {
      {
        space: space,
        syslog_drain_url: 'http://syslog.example.com/wow',
        credentials: { password: 'foo' }
      }
    }
    let(:bound_app) { VCAP::CloudController::AppModel.make(space: space) }
    let(:binding) { VCAP::CloudController::ServiceBinding.make(**binding_details) }
    let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(**service_instance_details) }

    context 'user provided services' do
      context 'app bindings' do
        it 'can successfully delete the record' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(204)

          get "/v3/service_credential_bindings/#{guid}", {}, admin_headers
          expect(last_response).to have_status_code(404)

          event = VCAP::CloudController::Event.find(type: 'audit.service_binding.delete')
          expect(event).to be
          expect(event.actee).to eq(binding.guid)
          expect(event.data).to include({
            'request' => {
              'app_guid' => bound_app.guid,
              'route_guid' => nil,
              'service_instance_guid' => service_instance.guid
            }
          })
        end
      end

      context 'key bindings' do
        let(:binding) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance) }
        it 'is not implemented' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(501)
        end
      end
    end

    context 'managed service instances' do
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }

      let(:broker_base_url) { service_instance.service_broker.broker_url }
      let(:broker_unbind_url) { "#{broker_base_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{binding.guid}" }

      let(:job) { VCAP::CloudController::PollableJobModel.last }
      let(:broker_unbind_status_code) { 200 }
      let(:broker_response) { {} }
      let(:query) do
        {
          service_id: service_instance.service_plan.service.unique_id,
          plan_id: service_instance.service_plan.unique_id,
          accepts_incomplete: true,
        }
      end

      context 'app binding' do
        it 'responds with a job resource' do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(202)
          expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
          expect(job.operation).to eq('service_bindings.delete')
          expect(job.resource_guid).to eq(binding.guid)
          expect(job.resource_type).to eq('service_credential_binding')

          get "/v3/jobs/#{job.guid}", nil, space_dev_headers

          expect(last_response).to have_status_code(200)
          expect(parsed_response['guid']).to eq(job.guid)
        end

        context 'when the service instance has an operation in progress' do
          it 'responds with 422' do
            service_instance.save_with_new_operation({}, { type: 'guacamole', state: 'in progress' })

            api_call.call admin_headers
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(include({
              'detail' => include('There is an operation in progress for the service instance'),
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            }))
          end
        end

        context 'when the service credential binding is still creating' do
          before do
            binding.save_with_attributes_and_new_operation(
              {},
              { type: 'create', state: 'in progress', broker_provided_operation: 'very important info' }
            )
          end

          context 'and the broker accepts the delete request' do
            before do
              @delete_stub = stub_request(:delete, broker_unbind_url).
                             with(query: query).
                             to_return(status: 202, body: '{"operation": "very important delete info"}', headers: {})

              @last_op_stub = stub_request(:get, "#{broker_unbind_url}/last_operation").
                              with(query: hash_including({
                  operation: 'very important delete info'
                })).
                              to_return(status: 200, body: '{"state": "in progress"}', headers: {})
            end

            it 'starts the route binding deletion' do
              api_call.call(admin_headers)
              expect(last_response).to have_status_code(202)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(@delete_stub).to have_been_requested.once
              expect(@last_op_stub).to have_been_requested

              binding.reload
              expect(binding.last_operation.type).to eq('delete')
              expect(binding.last_operation.state).to eq('in progress')
              expect(binding.last_operation.broker_provided_operation).to eq('very important delete info')
            end
          end

          context 'and the broker rejects the delete request' do
            before do
              stub_request(:delete, broker_unbind_url).
                with(query: query).
                to_return(status: 422, body: '{"error": "ConcurrencyError"}', headers: {})

              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 0, expected_failures: 1)
              binding.reload
            end

            it 'leaves the route binding in its current state' do
              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq('in progress')
              expect(binding.last_operation.broker_provided_operation).to eq('very important info')
            end
          end
        end

        describe 'the pollable job' do
          before do
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(202)

            stub_request(:delete, broker_unbind_url).
              with(query: query).
              to_return(status: broker_unbind_status_code, body: broker_response.to_json, headers: {})
          end

          it 'sends an unbind request with the right arguments to the service broker' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(
              a_request(:delete, broker_unbind_url).
                with(
                  query: query,
                )
            ).to have_been_made.once
          end

          context 'when the unbind completes synchronously' do
            it 'removes the binding' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(VCAP::CloudController::ServiceBinding.all).to be_empty
            end

            it 'completes the job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end

            it 'logs an audit event' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              event = VCAP::CloudController::Event.find(type: 'audit.service_binding.delete')
              expect(event).to be
              expect(event.actee).to eq(binding.guid)
              expect(event.data).to include({
                'request' => {
                  'app_guid' => bound_app.guid,
                  'route_guid' => nil,
                  'service_instance_guid' => service_instance.guid
                }
              })
            end
          end

          context 'when the unbind completes asynchronously' do
            let(:broker_unbind_status_code) { 202 }
            let(:operation) { Sham.guid }
            let(:broker_response) { { operation: operation } }
            let(:broker_binding_last_operation_url) { "#{broker_base_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{binding.guid}/last_operation" }
            let(:last_operation_status_code) { 200 }
            let(:description) { Sham.description }
            let(:state) { 'in progress' }
            let(:last_operation_body) do
              {
                description: description,
                state: state,
              }
            end

            before do
              stub_request(:get, broker_binding_last_operation_url).
                with(query: hash_including({
                  operation: operation
                })).
                to_return(status: last_operation_status_code, body: last_operation_body.to_json, headers: {})
            end

            it 'polls the last operation endpoint' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(
                a_request(:get, broker_binding_last_operation_url).
                  with(query: {
                    operation: operation,
                    service_id: service_instance.service_plan.service.unique_id,
                    plan_id: service_instance.service_plan.unique_id,
                  })
              ).to have_been_made.once
            end

            it 'updates the binding and job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              binding.reload
              expect(binding.last_operation.type).to eq('delete')
              expect(binding.last_operation.state).to eq(state)
              expect(binding.last_operation.description).to eq(description)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
            end

            it 'logs an audit event' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              event = VCAP::CloudController::Event.find(type: 'audit.service_binding.start_delete')
              expect(event).to be
              expect(event.actee).to eq(binding.guid)
              expect(event.data).to include({
                'request' => {
                  'app_guid' => bound_app.guid,
                  'route_guid' => nil,
              'service_instance_guid' => service_instance.guid
                }
              })
            end

            it 'enqueues the next fetch last operation job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(Delayed::Job.count).to eq(1)
            end

            it 'keeps track of the broker operation' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(Delayed::Job.count).to eq(1)

              Timecop.travel(Time.now + 1.minute)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(
                a_request(:get, broker_binding_last_operation_url).
                  with(query: {
                    operation: operation,
                    service_id: service_instance.service_plan.service.unique_id,
                    plan_id: service_instance.service_plan.unique_id,
                  })
              ).to have_been_made.twice
            end

            context 'last operation response is 200 OK and indicates success' do
              let(:state) { 'succeeded' }
              let(:last_operation_status_code) { 200 }

              it 'removes the binding' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                expect(VCAP::CloudController::ServiceBinding.all).to be_empty
              end

              it 'completes the job' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
              end
            end

            context 'last operation response is 410 Gone' do
              let(:last_operation_status_code) { 410 }
              let(:last_operation_body) { {} }

              it 'removes the binding' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                expect(VCAP::CloudController::ServiceBinding.all).to be_empty
              end

              it 'completes the job' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
              end
            end
          end

          context 'when the broker returns a failure' do
            let(:broker_unbind_status_code) { 418 }
            let(:broker_response) { 'nope' }

            it 'does not remove the binding' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(VCAP::CloudController::ServiceBinding.all).not_to be_empty
            end

            it 'puts the error details in the job' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
              expect(job.cf_api_error).not_to be_nil
              error = YAML.safe_load(job.cf_api_error)
              expect(error['errors'].first['code']).to eq(10009)
              expect(error['errors'].first['detail']).
                to include('The service broker rejected the request. Status Code: 418 I\'m a Teapot, Body: "nope"')
            end
          end
        end
      end

      context 'key bindings' do
        let(:binding) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance) }

        it 'is not implemented' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(501)
        end
      end
    end

    context 'permissions' do
      let(:db_check) {
        lambda {
          get "/v3/service_credential_bindings/#{guid}", {}, admin_headers
          expect(last_response).to have_status_code(404)
        }
      }

      let(:expected_codes_and_responses) do
        Hash.new(code: 403).tap do |h|
          h['admin'] = h['space_developer'] = { code: 204 }
          h['org_billing_manager'] = h['org_auditor'] = h['no_role'] = { code: 404 }
        end
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
    end

    describe 'invalid requests' do
      context 'when the binding does not exist' do
        let(:guid) { 'fake-binding' }

        it 'returns 404' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(404)
          expect(parsed_response['errors']).to include(include({
            'detail' => include('Service credential binding not found'),
            'title' => 'CF-ResourceNotFound',
            'code' => 10010,
          }))
        end
      end
    end
  end

  def expected_json(binding)
    {
      guid: binding.guid,
      created_at: iso8601,
      updated_at: iso8601,
      name: binding.name,
      last_operation: last_operation(binding),
      relationships: {
        service_instance: {
          data: {
            guid: binding.service_instance.guid
          }
        }
      },
      links: {
        self: {
          href: "#{link_prefix}/v3/service_credential_bindings/#{binding.guid}"
        },
        details: {
          href: "#{link_prefix}/v3/service_credential_bindings/#{binding.guid}/details"
        },
        parameters: {
          href: "#{link_prefix}/v3/service_credential_bindings/#{binding.guid}/parameters"
        },
        service_instance: {
          href: "#{link_prefix}/v3/service_instances/#{binding.service_instance.guid}"
        }
      }
    }.deep_merge(extra(binding))
  end

  def extra(binding)
    case binding
    when VCAP::CloudController::ServiceKey
      {
        type: 'key',
      }
    when VCAP::CloudController::ServiceBinding
      {
        type: 'app',
        last_operation: last_operation(binding),
        relationships: {
          app: {
            data: {
              guid: binding.app.guid
            }
          }
        },
        links: {
          app: {
            href: "#{link_prefix}/v3/apps/#{binding.app.guid}"
          }
        }
      }
    else
      raise 'not a binding'
    end
  end

  def last_operation(binding)
    if binding.try(:last_operation)
      {
        type: binding.last_operation.type,
        state: binding.last_operation.state,
        description: binding.last_operation.description,
        created_at: iso8601,
        updated_at: iso8601
      }
    else
      {
        type: 'create',
        state: 'succeeded',
        description: '',
        created_at: iso8601,
        updated_at: iso8601
      }
    end
  end

  def operate_on(binding)
    binding.save_with_new_operation(
      {
        type: 'create',
        state: 'succeeded',
        description: 'some description'
      }
    )
  end

  def stub_param_broker_request_for_binding(binding, binding_params, status: 200)
    instance = binding.service_instance
    broker_url = instance.service_broker.broker_url
    broker_binding_url = "#{broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}"

    stub_request(:get, /#{broker_binding_url}/).
      to_return(status: status, body: { parameters: binding_params }.to_json)
  end
end
