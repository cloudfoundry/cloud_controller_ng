require 'spec_helper'

RSpec.describe 'GET /internal/v4/log_access/:guid', type: [:api] do
  include RequestSpecHelper

  context 'when the guid is for a v3 app' do
    let(:app_model) { VCAP::CloudController::AppModel.make }

    it 'queries the proper v3 app' do
      get "/internal/v4/log_access/#{app_model.guid}", {}, admin_headers
      expect(last_response.status).to eq(200)
    end
  end

  context 'when the guid is for a v2 app' do
    let(:process_model) { VCAP::CloudController::ProcessModel.make }

    it 'queries the proper v2 app' do
      get "/internal/v4/log_access/#{process_model.guid}", {}, admin_headers
      expect(last_response.status).to eq(200)
    end
  end
end
