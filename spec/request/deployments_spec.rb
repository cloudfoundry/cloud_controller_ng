require 'spec_helper'

RSpec.describe 'Deployments' do
  let(:user) { make_developer_for_space(space) }
  let(:space) { app_model.space }
  let(:app_model) { droplet.app }
  let(:droplet) { VCAP::CloudController::DropletModel.make }

  let(:user_header) { headers_for(user, email: user_email, user_name: user_name) }
  let(:user_email) { Sham.email }
  let(:user_name) { 'some-username' }

  before do
    app_model.update(droplet_guid: droplet.guid)
  end

  describe 'POST /v3/deployments' do
    let(:create_request) do
      {
        relationships: {
          app: {
            data: {
              guid: app_model.guid
            }
          },
        }
      }
    end

    it 'should create a deployment object' do
      post '/v3/deployments', create_request.to_json, user_header
      expect(last_response.status).to eq(201)
      parsed_response = MultiJson.load(last_response.body)

      deployment = VCAP::CloudController::DeploymentModel.last

      expect(parsed_response).to be_a_response_like({
        'guid' => deployment.guid,
        'state' => 'DEPLOYING',
        'droplet' => {
          'guid' => droplet.guid
        },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'relationships' => {
          'app' => {
            'data' => {
              'guid' => app_model.guid
            }
          }
        },
        'links' => {
          'self' => {
            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
          },
          'app' => {
            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
          }
        }
      })
    end
  end
end
