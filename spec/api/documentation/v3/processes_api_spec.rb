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
    let(:process) { VCAP::CloudController::ProcessModel.make }
    let(:guid) { process.guid }

    example 'Get a Process' do
      do_request_with_error_handling
      parsed_response = JSON.parse(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response["guid"]).to eq(guid)
    end
  end

  delete '/v3/processes/:guid' do
    let!(:process) { VCAP::CloudController::ProcessModel.make }
    let(:guid) { process.guid }

    example 'Delete a Process' do
      expect {
        do_request_with_error_handling
      }.to change{ VCAP::CloudController::ProcessModel.count }.by(-1)
      expect(response_status).to eq(204)
    end
  end

  post "/v3/processes" do
    let(:space) { VCAP::CloudController::Space.make }
    let(:stack) { VCAP::CloudController::Stack.make }

    parameter :name, "Name of process", required: true
    parameter :memory, "Amount of memory (MB) allocated to each instance", required: true
    parameter :instances, "Number of instances", required: true
    parameter :disk_quota, "Amount of disk space (MB) allocated to each instance", required: true
    parameter :space_guid, "Guid of associated Space", required: true
    parameter :stack_guid, "Guid of associated Stack", required: true
    parameter :state, "Desired state of process"
    parameter :command, "Start command for process"
    parameter :buildpack, "Buildpack used to stage process"
    parameter :health_check_timeout, "Health check timeout for process"
    parameter :docker_image, "Name of docker image containing process"
    parameter :environment_json, "JSON key-value pairs for ENV variables"

    let(:name) { "process" }
    let(:memory) { 256 }
    let(:instances) { 2 }
    let(:disk_quota) { 1024 }
    let(:space_guid) { space.guid }
    let(:stack_guid) { stack.guid }

    let(:raw_post) { params.to_json }

    context "without a docker image" do
      example "Create a Process" do
        expect {
          do_request_with_error_handling
        }.to change{ VCAP::CloudController::ProcessModel.count }.by(1)
        parsed_response = JSON.parse(response_body)

        expect(response_status).to eq(201)
        expect(parsed_response["guid"]).to_not eq(nil)
      end
    end

    context "with a docker image" do
      let(:environment_json) { { "CF_DIEGO_BETA" => "true", "CF_DIEGO_RUN_BETA" => "true" } }
      let(:docker_image) { "cloudfoundry/hello" }

      example "Create a Docker Process" do
        expect {
          do_request_with_error_handling
        }.to change{ VCAP::CloudController::ProcessModel.count }.by(1)
        parsed_response = JSON.parse(response_body)

        expect(response_status).to eq(201)
        expect(parsed_response["guid"]).to_not eq(nil)
      end
    end
  end
end
