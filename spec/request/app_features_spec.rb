require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'App Features' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:admin_header) { admin_headers_for(user) }
  let(:org) { VCAP::CloudController::Organization.make(created_at: 3.days.ago) }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:service_binding_k8s_enabled) { true }
  let(:file_based_vcap_services_enabled) { false }
  let(:request_body_enabled) { { body: { enabled: true } } }
  let(:app_model) do
    VCAP::CloudController::AppModel.make(
      space: space,
      enable_ssh: true,
      service_binding_k8s_enabled: service_binding_k8s_enabled,
      file_based_vcap_services_enabled: file_based_vcap_services_enabled
    )
  end

  describe 'GET /v3/apps/:guid/features' do
    context 'getting a list of available features for the app' do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/features", nil, user_headers } }
      let(:features_response_object) do
        {
          'resources' => [
            {
              'name' => 'ssh',
              'description' => 'Enable SSHing into the app.',
              'enabled' => true
            },
            {
              'name' => 'revisions',
              'description' => 'Enable versioning of an application',
              'enabled' => true
            },
            {
              'name' => 'service-binding-k8s',
              'description' => 'Enable k8s service bindings for the app',
              'enabled' => true
            },
            {
              'name' => 'file-based-vcap-services',
              'description' => 'Enable file-based VCAP service bindings for the app',
              'enabled' => false
            }
          ],
          'pagination' =>
            {
              'total_results' => 4,
              'total_pages' => 1,
              'first' => { 'href' => "/v3/apps/#{app_model.guid}/features" },
              'last' => { 'href' => "/v3/apps/#{app_model.guid}/features" },
              'next' => nil,
              'previous' => nil
            }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 404 }.freeze)

        %w[admin admin_read_only global_auditor space_developer space_manager space_auditor org_manager
           space_supporter].each do |r|
          h[r] = { code: 200, response_object: features_response_object }
        end
        h
      end

      before do
        space.organization.add_user(user)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end

  describe 'GET /v3/apps/:guid/features/:name' do
    let(:expected_codes_and_responses) do
      h = Hash.new({ code: 404 }.freeze)

      %w[admin admin_read_only global_auditor space_developer space_manager space_auditor org_manager
         space_supporter].each do |r|
        h[r] = { code: 200, response_object: feature_response_object }
      end
      h
    end

    before do
      space.organization.add_user(user)
    end

    context 'ssh app feature' do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/features/ssh", nil, user_headers } }
      let(:feature_response_object) do
        {
          'name' => 'ssh',
          'description' => 'Enable SSHing into the app.',
          'enabled' => true
        }
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'revisions app feature' do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/features/revisions", nil, user_headers } }
      let(:feature_response_object) do
        {
          'name' => 'revisions',
          'description' => 'Enable versioning of an application',
          'enabled' => true
        }
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'service-binding-k8s app feature' do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/features/service-binding-k8s", nil, user_headers } }
      let(:feature_response_object) do
        {
          'name' => 'service-binding-k8s',
          'description' => 'Enable k8s service bindings for the app',
          'enabled' => true
        }
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'file-based-vcap-services app feature' do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/features/file-based-vcap-services", nil, user_headers } }
      let(:feature_response_object) do
        {
          'name' => 'file-based-vcap-services',
          'description' => 'Enable file-based VCAP service bindings for the app',
          'enabled' => false
        }
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end

  describe 'PATCH /v3/apps/:guid/features/:name' do
    let(:request_body) { { body: { enabled: false } } }

    before do
      space.organization.add_user(user)
    end

    context 'ssh app feature' do
      let(:api_call) { ->(user_headers) { patch "/v3/apps/#{app_model.guid}/features/ssh", request_body.to_json, user_headers } }
      let(:feature_response_object) do
        {
          'name' => 'ssh',
          'description' => 'Enable SSHing into the app.',
          'enabled' => false
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)

        %w[no_role org_auditor org_billing_manager].each { |r| h[r] = { code: 404 } }
        %w[admin space_developer].each { |r| h[r] = { code: 200, response_object: feature_response_object } }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          h['space_developer'] = { code: 403, errors: CF_ORG_SUSPENDED }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'revisions app feature' do
      let(:api_call) { ->(user_headers) { patch "/v3/apps/#{app_model.guid}/features/revisions", request_body.to_json, user_headers } }
      let(:feature_response_object) do
        {
          'name' => 'revisions',
          'description' => 'Enable versioning of an application',
          'enabled' => false
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        %w[no_role org_auditor org_billing_manager].each { |r| h[r] = { code: 404 } }
        %w[admin space_developer space_supporter].each do |r|
          h[r] = { code: 200, response_object: feature_response_object }
        end
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'service-binding-k8s app feature' do
      context 'when feature is enabled' do
        let(:service_binding_k8s_enabled) { true }
        let(:api_call) { ->(user_headers) { patch "/v3/apps/#{app_model.guid}/features/service-binding-k8s", request_body.to_json, user_headers } }
        let(:feature_response_object) do
          {
            'name' => 'service-binding-k8s',
            'description' => 'Enable k8s service bindings for the app',
            'enabled' => false
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
          %w[no_role org_auditor org_billing_manager].each { |r| h[r] = { code: 404 } }
          %w[admin space_developer].each { |r| h[r] = { code: 200, response_object: feature_response_object } }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

        context 'when organization is suspended' do
          let(:expected_codes_and_responses) do
            h = super()
            h['space_developer'] = { code: 403, errors: CF_ORG_SUSPENDED }
            h
          end

          before do
            org.update(status: VCAP::CloudController::Organization::SUSPENDED)
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end

      context 'when feature is disabled' do
        let(:service_binding_k8s_enabled) { false }
        let(:api_call) { ->(user_headers) { patch "/v3/apps/#{app_model.guid}/features/service-binding-k8s", request_body_enabled.to_json, user_headers } }

        let(:feature_response_object) do
          {
            'name' => 'service-binding-k8s',
            'description' => 'Enable k8s service bindings for the app',
            'enabled' => true
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
          %w[no_role org_auditor org_billing_manager].each { |r| h[r] = { code: 404 } }
          %w[admin space_developer].each { |r| h[r] = { code: 200, response_object: feature_response_object } }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

        context 'when file-based-vcap-services is enabled' do
          before do
            patch "/v3/apps/#{app_model.guid}/features/file-based-vcap-services", request_body_enabled.to_json, admin_header
          end

          it 'returns an error which states that both features cannot be enabled at the same time' do
            patch "/v3/apps/#{app_model.guid}/features/service-binding-k8s", request_body_enabled.to_json, admin_header

            expect(last_response.status).to eq(422)
            expect(parsed_response['errors'][0]['detail']).to eq("'file-based-vcap-services' and 'service-binding-k8s' features cannot be enabled at the same time.")
          end
        end
      end
    end

    context 'file-based-vcap-services app feature' do
      context 'when feature is enabled' do
        let(:service_binding_k8s_enabled) { false }
        let(:file_based_vcap_services_enabled) { true }
        let(:api_call) { ->(user_headers) { patch "/v3/apps/#{app_model.guid}/features/file-based-vcap-services", request_body.to_json, user_headers } }
        let(:feature_response_object) do
          {
            'name' => 'file-based-vcap-services',
            'description' => 'Enable file-based VCAP service bindings for the app',
            'enabled' => false
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
          %w[no_role org_auditor org_billing_manager].each { |r| h[r] = { code: 404 } }
          %w[admin space_developer].each { |r| h[r] = { code: 200, response_object: feature_response_object } }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

        context 'when organization is suspended' do
          let(:expected_codes_and_responses) do
            h = super()
            h['space_developer'] = { code: 403, errors: CF_ORG_SUSPENDED }
            h
          end

          before do
            org.update(status: VCAP::CloudController::Organization::SUSPENDED)
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end

      context 'when feature is disabled' do
        let(:service_binding_k8s_enabled) { false }
        let(:file_based_vcap_services_enabled) { false }
        let(:api_call) { ->(user_headers) { patch "/v3/apps/#{app_model.guid}/features/file-based-vcap-services", request_body_enabled.to_json, user_headers } }

        let(:feature_response_object) do
          {
            'name' => 'file-based-vcap-services',
            'description' => 'Enable file-based VCAP service bindings for the app',
            'enabled' => true
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
          %w[no_role org_auditor org_billing_manager].each { |r| h[r] = { code: 404 } }
          %w[admin space_developer].each { |r| h[r] = { code: 200, response_object: feature_response_object } }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

        context 'when service-binding-k8s is enabled' do
          before do
            patch "/v3/apps/#{app_model.guid}/features/service-binding-k8s", request_body_enabled.to_json, admin_header
          end

          it 'returns an error which states that both features cannot be enabled at the same time' do
            patch "/v3/apps/#{app_model.guid}/features/file-based-vcap-services", request_body_enabled.to_json, admin_header

            expect(last_response.status).to eq(422)
            expect(parsed_response['errors'][0]['detail']).to eq("'file-based-vcap-services' and 'service-binding-k8s' features cannot be enabled at the same time.")
          end
        end
      end
    end
  end
end
