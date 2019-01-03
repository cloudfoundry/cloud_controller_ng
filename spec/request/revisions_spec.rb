require 'spec_helper'

RSpec.describe 'Revisions' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: user_email, user_name: user_name) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:stack) { VCAP::CloudController::Stack.make }
  let(:user_email) { Sham.email }
  let(:user_name) { 'some-username' }
  let(:app_model) { VCAP::CloudController::AppModel.make(name: 'app_name', space: space) }
  let!(:revision) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 42) }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'GET /v3/apps/:guid/revisions/:revguid' do
    it 'gets a specific revision' do
      get "/v3/apps/#{app_model.guid}/revisions/#{revision.guid}", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'guid' => revision.guid,
          'version' => revision.version,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/#{revision.guid}"
            }
          }
        }
      )
    end
  end

  describe 'GET /v3/apps/:guid/revisions' do
    it 'gets a list of revisions for the app' do
      revision2 = VCAP::CloudController::RevisionModel.make(app: app_model, version: 43)

      get "/v3/apps/#{app_model.guid}/revisions?per_page=2", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 2,
            'total_pages' => 1,
            'first' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions?page=1&per_page=2"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions?page=1&per_page=2"
            },
            'next' => nil,
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => revision.guid,
              'version' =>  revision.version,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/#{revision.guid}"
                }
              }
            },
            {
              'guid' => revision2.guid,
              'version' =>  revision2.version,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/#{revision2.guid}"
                }
              }
            }
          ]
        }
      )
    end
  end
end
