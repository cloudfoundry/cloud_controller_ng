require 'spec_helper'
require 'actions/process_create_from_app_droplet'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/apps_spec.rb for better test parallelization

RSpec.describe 'Apps' do
  include_context 'apps request spec'

  describe 'PATCH /v3/apps/:guid/environment_variables' do
    before do
      space.organization.add_user(user)
    end

    let(:update_request) do
      {
        var: {
          override: 'new-value',
          new_key: 'brand-new-value'
        }
      }
    end
    let(:app_model) do
      VCAP::CloudController::AppModel.make(
        name: 'name1',
        space: space,
        desired_state: 'STOPPED',
        environment_variables: {
          override: 'original',
          preserve: 'keep'
        }
      )
    end
    let(:api_call) { ->(user_headers) { patch "/v3/apps/#{app_model.guid}/environment_variables", update_request.to_json, user_headers } }
    let(:app_model_response_object) do
      {
        'var' => {
          'override' => 'new-value',
          'new_key' => 'brand-new-value',
          'preserve' => 'keep'
        },
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" }
        }
      }
    end
    let(:expected_codes_and_responses) do
      h = Hash.new({ code: 404 }.freeze)
      %w[global_auditor admin_read_only org_manager space_auditor space_manager].each do |r|
        h[r] = { code: 403, errors: CF_NOT_AUTHORIZED }
      end
      h['admin'] = h['space_developer'] = h['space_supporter'] = {
        code: 200,
        response_object: app_model_response_object
      }
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

  describe 'GET /v3/apps/:guid/environment_variables' do
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'my_app', space: space, desired_state: 'STARTED', environment_variables: { meep: 'moop' }) }
    let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/environment_variables", nil, user_headers } }
    let(:app_model_response_object) do
      {
        var: {
          meep: 'moop'
        },
        links: {
          self: { href: "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
          app: { href: "#{link_prefix}/v3/apps/#{app_model.guid}" }
        }
      }
    end

    before do
      space.organization.add_user(user)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 404 }.freeze)
        h['global_auditor'] = h['org_manager'] = h['space_auditor'] = h['space_manager'] = { code: 403 }
        h['admin'] = h['admin_read_only'] = h['space_developer'] = h['space_supporter'] = {
          code: 200,
          response_object: app_model_response_object
        }
        h
      end
    end

    context 'when the space_developer_env_var_visibility feature flag is disabled' do
      before do
        VCAP::CloudController::FeatureFlag.make(name: 'space_developer_env_var_visibility', enabled: false, error_message: nil)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) do
          h = Hash.new({ code: 404 }.freeze)
          h['global_auditor'] = h['org_manager'] = h['space_auditor'] = h['space_manager'] = h['space_developer'] = h['space_supporter'] = { code: 403 }
          h['admin'] = h['admin_read_only'] = {
            code: 200,
            response_object: app_model_response_object
          }
          h
        end
      end
    end

    context 'when the encryption_key_label is invalid' do
      before do
        allow_any_instance_of(ErrorPresenter).to receive(:raise_500?).and_return(false)
      end

      it 'fails to decrypt the environment variables and returns a 500 error' do
        app_model # ensure that app model is created before run_cipher is mocked to throw an error
        allow(VCAP::CloudController::Encryptor).to receive(:run_cipher).and_raise(VCAP::CloudController::Encryptor::EncryptorError)
        api_call.call(admin_headers)

        expect(last_response).to have_status_code(500)
        expect(parsed_response['errors'].first['detail']).to match(/Error while processing encrypted data/i)
      end
    end
  end

  describe 'GET /v3/apps/:guid/permissions' do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'name1', space: space, desired_state: 'STOPPED') }
    let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/permissions", nil, user_headers } }

    let(:read_all_response) do
      {
        read_basic_data: true,
        read_sensitive_data: true
      }
    end

    let(:read_basic_response) do
      {
        read_basic_data: true,
        read_sensitive_data: false
      }
    end

    let(:expected_codes_and_responses) do
      h = Hash.new({ code: 404 }.freeze)
      h['admin'] = { code: 200, response_object: read_all_response }
      h['admin_read_only'] = { code: 200, response_object: read_all_response }
      h['global_auditor'] = { code: 200, response_object: read_basic_response }
      h['org_manager'] = { code: 200, response_object: read_basic_response }
      h['space_manager'] = { code: 200, response_object: read_basic_response }
      h['space_auditor'] = { code: 200, response_object: read_basic_response }
      h['space_developer'] = { code: 200, response_object: read_all_response }
      h['space_supporter'] = { code: 200, response_object: read_basic_response }
      h
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
  end
end
