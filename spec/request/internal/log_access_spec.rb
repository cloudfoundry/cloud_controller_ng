require 'spec_helper'

RSpec.describe 'Internal Log Access Endpoint' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'GET /internal/log_access/:app_guid' do
    context 'when the user has access to view the logs for the app' do
      it 'returns 200' do
        get "/internal/log_access/#{app_model.guid}", nil, user_header
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe 'GET /internal/v4/log_access/:app_guid' do
    context 'when the user has access to view the logs for the app' do
      it 'returns 200' do
        get "/internal/v4/log_access/#{app_model.guid}", nil, user_header
        expect(last_response.status).to eq(200)
      end
    end
  end
end
