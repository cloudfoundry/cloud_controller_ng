require 'spec_helper'

RSpec.describe 'Feature Flags Request' do
  describe 'GET /v3/feature_flags' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }
    let(:flag_defaults) { VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS }
    let(:flag_names_sorted) { flag_defaults.keys.sort }

    it 'returns feature flags in alphabetical order' do
      get '/v3/feature_flags', nil, headers

      expect(last_response.status).to eq(200)
      flag_names_in_response = parsed_response['resources'].map { |flag| flag['name'] }
      expect(flag_names_in_response).to eq(flag_names_sorted.map(&:to_s))
    end

    context 'filtering timestamps on update' do
      # before must occur before the let! otherwise the resources will be created with
      # update_on_create: true
      before do
        VCAP::CloudController::FeatureFlag.plugin :timestamps, update_on_create: false
      end

      let!(:resource_1) { VCAP::CloudController::FeatureFlag.make(name: 'set_roles_by_username', updated_at: '2020-05-26T18:47:01Z') }
      let!(:resource_2) { VCAP::CloudController::FeatureFlag.make(name: 'task_creation', updated_at: '2020-05-26T18:47:02Z') }
      let!(:resource_3) { VCAP::CloudController::FeatureFlag.make(name: 'user_org_creation', updated_at: '2020-05-26T18:47:03Z') }
      let!(:resource_4) { VCAP::CloudController::FeatureFlag.make(name: 'unset_roles_by_username', updated_at: '2020-05-26T18:47:04Z') }

      after do
        VCAP::CloudController::FeatureFlag.plugin :timestamps, update_on_create: true
      end

      it 'filters' do
        get '/v3/feature_flags?updated_ats[gt]=2020-05-26T18:47:02Z', nil, admin_headers

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to contain_exactly('user_org_creation', 'unset_roles_by_username')
      end
    end

    context 'filtering timestamps on created_ats' do
      it 'filters' do
        get '/v3/feature_flags?created_ats[gt]=2020-05-26T18:47:04Z', nil, admin_headers

        expect(last_response).to have_status_code(400)
        expect(last_response).to have_error_message("The query parameter is invalid: Filtering by 'created_ats' is not allowed on this resource.")
      end
    end
  end

  describe 'GET /v3/feature_flags/:name' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }

    context 'there is not an override' do
      it 'returns details of the requested feature flag when ' do
        get '/v3/feature_flags/diego_docker', nil, headers
        expect(last_response.status).to eq 200
        expect(parsed_response).to be_a_response_like(
          {
            'updated_at' => nil,
            'name' => 'diego_docker',
            'enabled' => false,
            'custom_error_message' => nil,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/feature_flags/diego_docker"
              }
            }
          }
        )
      end
    end

    context 'there is an override' do
      let(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: 'error') }
      it 'returns details of the requested feature flag when there is an override' do
        get "/v3/feature_flags/#{feature_flag.name}", nil, headers
        expect(last_response.status).to eq 200
        expect(parsed_response).to be_a_response_like(
          {
            'updated_at' => iso8601,
            'name' => feature_flag.name,
            'enabled' => feature_flag.enabled,
            'custom_error_message' => feature_flag.error_message,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/feature_flags/diego_docker"
              }
            }
          }
        )
      end
    end
  end

  describe 'PATCH /v3/feature_flags/:name' do
    let(:feature_flag) { VCAP::CloudController::FeatureFlag.new(name: 'diego_docker', enabled: true, error_message: 'error') }
    let(:patch_body) {
      { 'enabled' => feature_flag.enabled,
        'custom_error_message' => feature_flag.error_message,
      }
    }

    context 'user is not admin' do
      let(:user) { make_user }
      let(:headers) { headers_for(user) }

      it 'returns 403 error' do
        patch '/v3/feature_flags/diego_docker', patch_body.to_json, headers
        expect(last_response.status).to eq 403
      end
    end

    context 'user is admin' do
      it 'returns updated feature flag' do
        patch "/v3/feature_flags/#{feature_flag.name}", patch_body.to_json, admin_headers
        expect(last_response.status).to eq 200
        expect(parsed_response).to be_a_response_like(
          {
            'updated_at' => iso8601,
            'name' => feature_flag.name,
            'enabled' => feature_flag.enabled,
            'custom_error_message' => feature_flag.error_message,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/feature_flags/diego_docker"
              }
            }
          }
        )
      end
    end
  end
end
