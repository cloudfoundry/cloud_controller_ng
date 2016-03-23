require 'rails_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Processes (Experimental)', type: :api do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user)['HTTP_AUTHORIZATION'] }
  header 'AUTHORIZATION', :user_header

  def do_request_with_error_handling
    do_request
    if response_status == 500
      error = JSON.parse(response_body)
      ap error
      raise error['description']
    end
  end

  put '/v3/apps/:guid/processes/:type/scale' do
    body_parameter :instances, 'Number of instances'
    body_parameter :memory_in_mb, 'The memory in mb allocated per instance'
    body_parameter :disk_in_mb, 'The disk in mb allocated per instance'

    let(:instances) { 3 }
    let(:memory_in_mb) { 100 }
    let(:disk_in_mb) { 100 }
    let(:guid) { app_model.guid }
    let(:type) { process.type }
    let(:raw_post) { body_parameters }

    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::AppFactory.make(app_guid: app_model.guid, space: app_model.space) }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    header 'Content-Type', 'application/json'

    example 'Scaling a Process from its App' do
      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::Event.count }.by(1)
      process.reload

      expected_response = {
        'guid'         => process.guid,
        'type'         => process.type,
        'command'      => process.command,
        'instances'    => instances,
        'memory_in_mb' => memory_in_mb,
        'disk_in_mb'   => disk_in_mb,
        'created_at'   => iso8601,
        'updated_at'   => iso8601,
        'links' => {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{process.app_guid}" },
          'space' => { 'href' => "/v2/spaces/#{process.space_guid}" },
        },
      }

      parsed_response = JSON.parse(response_body)
      expect(response_status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  delete '/v3/apps/:guid/processes/:type/instances/:index' do
    body_parameter :guid, 'App guid'
    body_parameter :type, 'The type of instance', example_values: ['web', 'worker']
    body_parameter :index, 'The index of the instance to terminate'

    let(:guid) { app_model.guid }
    let(:type) { process.type }
    let(:index) { 0 }

    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::AppFactory.make(app_guid: app_model.guid, space: app_model.space) }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Terminating a Process instance from its App' do
      do_request_with_error_handling

      expect(response_status).to eq(204)
    end
  end
end
