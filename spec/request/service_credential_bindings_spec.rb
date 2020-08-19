require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'v3 service credential bindings' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:other_space) { VCAP::CloudController::Space.make }

  describe 'GET /v3/service_credential_bindings' do
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
      let(:api_call) { ->(user_headers) { get '/v3/service_credential_bindings', nil, user_headers } }

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
          get "/v3/service_credential_bindings?service_instance_names=#{instance.name},#{other_instance.name}", nil, admin_headers
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
          get "/v3/service_credential_bindings?service_instance_guids=#{instance.guid},#{other_instance.guid}", nil, admin_headers
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
          get "/v3/service_credential_bindings?names=#{key_binding.name},#{other_app_binding.name}", nil, admin_headers
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
      let(:valid_query_params) { [
        'page', 'per_page', 'order_by',
        'created_ats', 'updated_ats',
        'names',
        'service_instance_guids', 'service_instance_names',
        'app_guids', 'app_names',
        'include',
        'type'
      ]
      }

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
      end
    end
  end

  describe 'GET /v3/service_credential_bindings/:app_guid' do
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
