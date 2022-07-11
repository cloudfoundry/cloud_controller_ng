require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'App Features' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:admin_header) { admin_headers_for(user) }
  let(:org) { VCAP::CloudController::Organization.make(created_at: 3.days.ago) }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:app_model) { VCAP::CloudController::AppModel.make(space: space, enable_ssh: true) }

  describe 'GET /v3/apps/:guid/features' do
    context 'getting a list of available features for the app' do
      let(:api_call) { lambda { |user_headers| get "/v3/apps/#{app_model.guid}/features", nil, user_headers } }
      let(:features_response_object) do
        {
          'resources' => [
            {
              'name' => 'ssh',
              'description' => 'Enable SSHing into the app.',
              'enabled' => true,
            },
            {
              'name' => 'revisions',
              'description' => 'Enable versioning of an application',
              'enabled' => true
            }
          ],
          'pagination' =>
            {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => { 'href' => "/v3/apps/#{app_model.guid}/features" },
              'last' => { 'href' => "/v3/apps/#{app_model.guid}/features" },
              'next' => nil,
              'previous' => nil,
            },
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
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
      h = Hash.new(code: 404)
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
      let(:api_call) { lambda { |user_headers| get "/v3/apps/#{app_model.guid}/features/ssh", nil, user_headers } }
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
      let(:api_call) { lambda { |user_headers| get "/v3/apps/#{app_model.guid}/features/revisions", nil, user_headers } }
      let(:feature_response_object) do
        {
          'name' => 'revisions',
          'description' => 'Enable versioning of an application',
          'enabled' => true
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
      let(:api_call) { lambda { |user_headers| patch "/v3/apps/#{app_model.guid}/features/ssh", request_body.to_json, user_headers } }
      let(:feature_response_object) do
        {
          'name' => 'ssh',
          'description' => 'Enable SSHing into the app.',
          'enabled' => false
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
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
      let(:api_call) { lambda { |user_headers| patch "/v3/apps/#{app_model.guid}/features/revisions", request_body.to_json, user_headers } }
      let(:feature_response_object) do
        {
          'name' => 'revisions',
          'description' => 'Enable versioning of an application',
          'enabled' => false
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
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
  end
end
