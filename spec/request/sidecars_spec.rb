require 'spec_helper'

RSpec.describe 'Sidecars' do
  let(:app_model) { FactoryBot.create(:app) }
  let(:user_header) { headers_for(user) }
  let(:user) { VCAP::CloudController::User.make }

  before do
    app_model.space.organization.add_user(user)
    app_model.space.add_developer(user)
  end

  describe 'POST /v3/apps/:guid/sidecars' do
    let(:sidecar_params) {
      {
          name: 'sidecar_one',
          command: 'bundle exec rackup',
          process_types: ['web', 'other_worker']
      }
    }

    it 'creates a sidecar for an app' do
      expect {
        post "/v3/apps/#{app_model.guid}/sidecars", sidecar_params.to_json, user_header
      }.to change { VCAP::CloudController::SidecarModel.count }.by(1)

      expect(last_response.status).to eq(201), last_response.body
      sidecar = VCAP::CloudController::SidecarModel.last

      expected_response = {
        'guid' => sidecar.guid,
        'name' => 'sidecar_one',
        'command' => 'bundle exec rackup',
        'process_types' => ['other_worker', 'web'],
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'relationships' => {
          'app' => {
            'data' => {
              'guid' => app_model.guid
            }
          }
        }
      }

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
end
