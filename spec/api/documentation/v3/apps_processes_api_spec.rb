require 'spec_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Apps (Experimental)', type: :api do
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

  get '/v3/apps/:guid/processes' do
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, 'Number of results per page', valid_values: '1-5000'
    parameter :process_guid, 'GUID of process', required: false

    let(:space) { VCAP::CloudController::Space.make }
    let(:stack) { VCAP::CloudController::Stack.make }
    let!(:process) { VCAP::CloudController::AppFactory.make(space_guid: space.guid) }
    let(:process_guid) { process.guid }
    let(:process_type) { process.type }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { app_model.guid }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      app_model.add_process_by_guid(process_guid)
    end

    example 'List associated processes' do
      expected_response = {
        'pagination' => {
          'total_results' => 1,
          'first'         => { 'href' => "/v3/apps/#{guid}/processes?page=1&per_page=50" },
          'last'          => { 'href' => "/v3/apps/#{guid}/processes?page=1&per_page=50" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources'  => [
          {
            'guid' => process_guid,
            'type' => process_type,
          }
        ]
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
    end
  end

  put '/v3/apps/:guid/processes' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:stack) { VCAP::CloudController::Stack.make }

    parameter :process_guid, 'GUID of process', required: true

    let!(:process) { VCAP::CloudController::AppFactory.make(space_guid: space.guid) }
    let(:process_guid) { process.guid }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { app_model.guid }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    example 'Add a Process' do
      expect {
        do_request_with_error_handling
      }.not_to change { VCAP::CloudController::App.count }

      expect(response_status).to eq(204)
      expect(app_model.reload.processes.first).to eq(process.reload)
    end
  end

  delete '/v3/apps/:guid/processes' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:stack) { VCAP::CloudController::Stack.make }

    parameter :process_guid, 'GUID of process', required: true

    let!(:process) { VCAP::CloudController::AppFactory.make(space_guid: space.guid) }
    let(:process_guid) { process.guid }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { app_model.guid }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)

      app_model.add_process_by_guid(process_guid)
    end

    example 'Remove a Process' do
      expect {
        do_request_with_error_handling
      }.not_to change { VCAP::CloudController::App.count }

      expect(response_status).to eq(204)
      expect(app_model.reload.processes).to eq([])
    end
  end
end
