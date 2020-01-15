require 'spec_helper'

RSpec.describe 'App Features' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space: space, enable_ssh: true) }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'GET /v3/apps/:guid/features' do
    it 'gets a list of available features for the app' do
      get "/v3/apps/#{app_model.guid}/features", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
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
      )
    end
  end

  describe 'ssh feature' do
    describe 'GET /v3/apps/:guid/features/ssh' do
      it 'gets a specific app feature' do
        get "/v3/apps/#{app_model.guid}/features/ssh", nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'name' => 'ssh',
            'description' => 'Enable SSHing into the app.',
            'enabled' => true
          }
        )
      end
    end

    describe 'PATCH /v3/apps/:guid/features/ssh' do
      it 'enables/disables the specific app feature' do
        request_body = { body: { enabled: false } }
        patch "/v3/apps/#{app_model.guid}/features/ssh", request_body.to_json, user_header

        expect(last_response.status).to eq(200)
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like({
          'name' => 'ssh',
          'description' => 'Enable SSHing into the app.',
          'enabled' => false
        })
      end
    end
  end
end
