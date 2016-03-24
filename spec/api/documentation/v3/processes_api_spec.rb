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
