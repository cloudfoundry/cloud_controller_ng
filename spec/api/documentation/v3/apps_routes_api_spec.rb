require 'spec_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'App Routes (Experimental)', type: :api do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user)['HTTP_AUTHORIZATION'] }
  header 'AUTHORIZATION', :user_header

  def do_request_with_error_handling
    do_request
    if response_status == 500
      error = MultiJson.load(response_body)
      ap error
      raise error['description']
    end
  end

  # get '/v3/apps/:guid/routes' do
  # end

  put '/v3/apps/:guid/routes' do
    parameter :route_guid, 'GUID of the route', required: true

    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }

    let!(:route) { VCAP::CloudController::Route.make(space_guid: space_guid) }
    let(:route_guid) { route.guid }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { app_model.guid }

    let(:web_process) { VCAP::CloudController::AppFactory.make(space_guid: space_guid, type: 'web') }
    let(:worker_process) { VCAP::CloudController::AppFactory.make(space_guid: space_guid, type: 'worker_process') }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      app_model.add_process(web_process)
      app_model.add_process(worker_process)
    end

    example 'Add a Route' do
      expect {
        do_request_with_error_handling
      }.not_to change { VCAP::CloudController::App.count }

      expect(response_status).to eq(204)
      expect(app_model.routes).to eq([route])
      expect(web_process.reload.routes).to eq([route])
      expect(worker_process.reload.routes).to be_empty
    end
  end
end
