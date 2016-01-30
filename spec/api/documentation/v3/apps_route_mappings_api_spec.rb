require 'rails_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'App Routes (Experimental)', type: :api do
  let(:iso8601) { /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.freeze }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user)['HTTP_AUTHORIZATION'] }
  header 'AUTHORIZATION', :user_header

  def do_request_with_error_handling
    do_request
    if response_status > 399
      error = MultiJson.load(response_body)
      ap({ response_status: response_status, error: error })
      raise error['description']
    end
  end

  post '/v3/apps/:guid/route_mappings' do
    body_parameter :"relationships[route][guid]", 'Guid for a particular route', scope: [:relationships, :route], required: true
    body_parameter :"relationships[process][type]", 'Type for a particular process to map route to', scope: [:relationships, :process], default: 'web'

    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }

    let!(:route) { VCAP::CloudController::Route.make(space_guid: space_guid) }
    let(:route_guid) { route.guid }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { app_model.guid }

    let(:web_process) { VCAP::CloudController::AppFactory.make(space_guid: space_guid, type: 'web') }
    let(:worker_process) { VCAP::CloudController::AppFactory.make(space_guid: space_guid, type: 'worker_process') }

    let(:raw_post) do
      MultiJson.load(body_parameters).
        merge(
          {
            relationships: {
              route:   { guid: route_guid },
              process: { type: 'web' },
            }
          }).to_json
    end
    header 'Content-Type', 'application/json'

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      app_model.add_process(web_process)
      app_model.add_process(worker_process)
    end

    example 'Create a route mapping' do
      expect {
        do_request_with_error_handling
      }.not_to change { VCAP::CloudController::App.count }

      expect(response_status).to eq(201)
      expect(app_model.routes).to eq([route])
      expect(web_process.reload.routes).to eq([route])
      expect(worker_process.reload.routes).to be_empty
    end
  end
end
