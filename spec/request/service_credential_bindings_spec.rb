require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'v3 service credential bindings' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:other_space) { VCAP::CloudController::Space.make }

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
            page per_page order_by created_ats updated_ats names service_instance_guids service_instance_names
            app_guids app_names include type
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

  describe 'GET /v3/service_credential_bindings/:missing_key' do
    let(:api_call) { ->(user_headers) { get '/v3/service_credential_bindings/no-binding', nil, user_headers } }

    let(:expected_codes_and_responses) do
      Hash.new(code: 404)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
  end

  describe 'GET /v3/service_credential_bindings/:key_guid' do
    let(:key) { VCAP::CloudController::ServiceKey.make(service_instance: instance) }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:api_call) { ->(user_headers) { get "/v3/service_credential_bindings/#{key.guid}", nil, user_headers } }
    let(:expected_object) { expected_json(key) }

    context 'global roles' do
      let(:expected_codes_and_responses) do
        Hash.new({ code: 200, response_object: expected_object })
      end

      it_behaves_like 'permissions for single object endpoint', GLOBAL_SCOPES
    end

    context 'local roles' do
      context 'user is in the original space of the service instance' do
        let(:expected_codes_and_responses) do
          Hash.new({ code: 200, response_object: expected_object }).tap do |h|
            h['org_auditor'] = { code: 404 }
            h['org_billing_manager'] = { code: 404 }
            h['no_role'] = { code: 404 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', LOCAL_ROLES
      end

      context 'user is in a space that the service instance is shared to' do
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: other_space) }

        before do
          instance.add_shared_space(space)
        end

        let(:api_call) { ->(user_headers) { get "/v3/service_credential_bindings/#{key.guid}", nil, user_headers } }

        let(:expected_codes_and_responses) do
          Hash.new(code: 404)
        end

        it_behaves_like 'permissions for single object endpoint', LOCAL_ROLES
      end
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

  describe 'GET /v3/service_credential_bindings/:app_binding_guid' do
    let(:app_to_bind_to) { VCAP::CloudController::AppModel.make(space: space) }
    let(:app_binding) do
      VCAP::CloudController::ServiceBinding.make(service_instance: instance, app: app_to_bind_to).tap do |binding|
        operate_on(binding)
      end
    end
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:api_call) { ->(user_headers) { get "/v3/service_credential_bindings/#{app_binding.guid}", nil, user_headers } }
    let(:expected_object) { expected_json(app_binding) }

    context 'global roles' do
      let(:expected_codes_and_responses) do
        Hash.new({ code: 200, response_object: expected_object })
      end

      it_behaves_like 'permissions for single object endpoint', GLOBAL_SCOPES
    end

    context 'local roles' do
      let(:expected_codes_and_responses) do
        Hash.new({ code: 200, response_object: expected_object }).tap do |h|
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
        end
      end

      context 'user is in the original space of the service instance' do
        it_behaves_like 'permissions for single object endpoint', LOCAL_ROLES
      end

      context 'user is in a space that the service instance is shared to' do
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: other_space) }

        before do
          instance.add_shared_space(space)
        end

        context 'the app is in the users space' do
          it_behaves_like 'permissions for single object endpoint', LOCAL_ROLES
        end

        context 'the app is not in the users space' do
          let(:app_to_bind_to) { VCAP::CloudController::AppModel.make(space: other_space) }

          let(:expected_codes_and_responses) do
            Hash.new(code: 404)
          end

          it_behaves_like 'permissions for single object endpoint', LOCAL_ROLES
        end
      end
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

  describe 'GET /v3/service_credential_bindings/:guid' do
    let(:binding) { VCAP::CloudController::ServiceBinding.make }

    describe 'query params' do
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
      let(:credhub_response_body) { { data: [value: credentials] }.to_json }
      let!(:credhub_server_stub) {
        stub_request(:get, "#{credhub_url}/api/v1/data?name=#{key_binding.credhub_reference}&current=true").
          with(headers: {
            'Authorization' => 'Bearer my-favourite-access-token',
            'Content-Type'  => 'application/json'
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
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => 'cred does not exist',
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
        end
      end

      context 'when credhub returns an error' do
        let(:guid) { key_binding.guid }
        let(:credhub_response_status) { 500 }
        let(:credhub_response_body) { nil }

        it 'returns an error' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => 'Server error, status: 500',
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
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
      last_operation: nil,
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
    if binding.last_operation.present?
      {
        type: binding.last_operation.type,
        state: binding.last_operation.state,
        description: binding.last_operation.description,
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
end
