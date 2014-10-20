require 'spec_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Processes (Experimental)', type: :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  header "AUTHORIZATION", :admin_auth_header

  def do_request_with_error_handling
    do_request
    if response_status == 500
      error = JSON.parse(response_body)
      ap error
      raise error['description']
    end
  end

  get '/v3/processes/:guid' do
    parameter :guid, "Process GUID"
    let(:process) { VCAP::CloudController::ProcessModel.make }
    let(:guid) { process.guid }

    example 'Get a process' do
      do_request_with_error_handling
      parsed_response = JSON.parse(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response["guid"]).to eq(guid)
    end
  end
end
