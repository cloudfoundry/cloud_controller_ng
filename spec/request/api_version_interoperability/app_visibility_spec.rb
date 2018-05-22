require 'spec_helper'

RSpec.describe 'App visibility between API versions' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  context 'when creating an app on the v2 api' do
    it 'is visible on the v3 api' do
      request_body = {
        name: 'v2-app',
        space_guid: space.guid
      }
      post '/v2/apps', MultiJson.encode(request_body), user_header

      expect(last_response.status).to be 201
      app_guid = parsed_response['metadata']['guid']

      get "/v3/apps/#{app_guid}", nil, user_header

      expect(last_response.status).to eq 200
    end
  end

  context 'when creating an app on the v3 api' do
    it 'is visible on the v2 api' do
      request_body = {
        name: 'v3-app',
        relationships: { space: { data: { guid: space.guid } } }
      }
      post '/v3/apps', MultiJson.encode(request_body), user_header

      expect(last_response.status).to be 201
      app_guid = parsed_response['guid']

      get "/v2/apps/#{app_guid}", nil, user_header

      expect(last_response.status).to eq(200), last_response.body
    end
  end
end
