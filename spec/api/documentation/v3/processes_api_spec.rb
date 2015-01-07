require 'spec_helper'
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

  get '/v3/processes' do
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, 'Number of results per page', valid_values: '1-5000'

    let(:name1) { 'my_process1' }
    let(:name2) { 'my_process2' }
    let(:name3) { 'my_process3' }
    let!(:process1) { VCAP::CloudController::App.make(name: name1, space: space) }
    let!(:process2) { VCAP::CloudController::App.make(name: name2, space: space) }
    let!(:process3) { VCAP::CloudController::App.make(name: name3, space: space) }
    let!(:process4) { VCAP::CloudController::App.make(space: VCAP::CloudController::Space.make) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:page) { 1 }
    let(:per_page) { 2 }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'List all Processes' do
      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'first'         => { 'href' => '/v3/processes?page=1&per_page=2' },
          'last'          => { 'href' => '/v3/processes?page=2&per_page=2' },
          'next'          => { 'href' => '/v3/processes?page=2&per_page=2' },
          'previous'      => nil,
        },
        'resources'  => [
          {
            'guid'     => process1.guid,
            'type'     => process1.type,
          },
          {
            'guid'     => process2.guid,
            'type'     => process2.type,
          }
        ]
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
    end
  end

  get '/v3/processes/:guid' do
    let(:process) { VCAP::CloudController::AppFactory.make }
    let(:guid) { process.guid }
    let(:type) { process.type }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Get a Process' do
      expected_response = {
        'guid'     => guid,
        'type'     => type,
      }

      do_request_with_error_handling
      parsed_response = MultiJson.load(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
    end
  end

  delete '/v3/processes/:guid' do
    let!(:process) { VCAP::CloudController::AppFactory.make }
    let(:guid) { process.guid }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    example 'Delete a Process' do
      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::App.count }.by(-1)
      expect(response_status).to eq(204)
    end
  end

  patch '/v3/processes/:guid' do
    let(:buildpack_model) { VCAP::CloudController::Buildpack.make(name: 'another-buildpack') }
    let(:process) { VCAP::CloudController::AppFactory.make }

    before do
      process.space.organization.add_user user
      process.space.add_developer user
    end

    parameter :memory, 'Amount of memory (MB) allocated to each instance'
    parameter :instances, 'Number of instances'
    parameter :disk_quota, 'Amount of disk space (MB) allocated to each instance'
    parameter :space_guid, 'Guid of associated Space'
    parameter :stack_guid, 'Guid of associated Stack'
    parameter :state, 'Desired state of process'
    parameter :command, 'Start command for process'
    parameter :buildpack, 'Buildpack used to stage process'
    parameter :health_check_timeout, 'Health check timeout for process'
    parameter :docker_image, 'Name of docker image containing process'
    parameter :environment_json, 'JSON key-value pairs for ENV variables'
    parameter :type, 'Type of the process'

    let(:memory) { 2555 }
    let(:instances) { 2 }
    let(:disk_quota) { 2048 }
    let(:space_guid) { process.space.guid }
    let(:stack_guid) { process.stack.guid }
    let(:command) { 'X' }
    let(:state) { 'STARTED' }
    let(:buildpack) { buildpack_model.name }
    let(:health_check_timeout) { 70 }
    let(:environment_json) { { 'foo' => 'bar' } }
    let(:type) { 'worker' }

    let(:guid) { process.guid }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'Updating a Process' do
      expected_response = {
        'guid' => guid,
        'type' => type,
      }
      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::Event.count }.by(1)
      parsed_response = JSON.parse(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)

      process.reload
      expect(process.state).to eq(state)
      expect(process.command).to eq(command)
      expect(process.memory).to eq(memory)
      expect(process.instances).to eq(instances)
      expect(process.disk_quota).to eq(disk_quota)
      expect(process.buildpack).to eq(buildpack_model)
      expect(process.health_check_timeout).to eq(health_check_timeout)
      expect(process.environment_json).to eq(environment_json)
      expect(process.type).to eq(type)
    end
  end

  post '/v3/processes' do
    let(:buildpack_model) { VCAP::CloudController::Buildpack.make(name: 'another-buildpack') }
    let(:space) { VCAP::CloudController::Space.make }
    let(:stack) { VCAP::CloudController::Stack.make }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    parameter :name, 'Name of process'
    parameter :memory, 'Amount of memory (MB) allocated to each instance'
    parameter :instances, 'Number of instances'
    parameter :disk_quota, 'Amount of disk space (MB) allocated to each instance'
    parameter :space_guid, 'Guid of associated Space', required: true
    parameter :stack_guid, 'Guid of associated Stack'
    parameter :state, 'Desired state of process'
    parameter :command, 'Start command for process'
    parameter :buildpack, 'Buildpack used to stage process'
    parameter :health_check_timeout, 'Health check timeout for process'
    parameter :docker_image, 'Name of docker image containing process'
    parameter :environment_json, 'JSON key-value pairs for ENV variables'
    parameter :type, 'Type of the process'

    let(:name) { 'process' }
    let(:memory) { 256 }
    let(:instances) { 2 }
    let(:disk_quota) { 1024 }
    let(:space_guid) { space.guid }
    let(:stack_guid) { stack.guid }
    let(:state) { 'STOPPED' }
    let(:command) { 'run me' }
    let(:buildpack) { buildpack_model.name }
    let(:health_check_timeout) { 70 }
    let(:environment_json) { { foo: 'bar' } }
    let(:type) { 'worker' }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    context 'without a docker image' do
      example 'Create a Process' do
        expected_response = {
          'guid' => /^[a-z0-9\-]+$/,
          'type' => type,
        }
        expect {
          do_request_with_error_handling
        }.to change { VCAP::CloudController::App.count }.by(1)
        parsed_response = JSON.parse(response_body)

        expect(response_status).to eq(201)
        expect(parsed_response).to match(expected_response)

        process = VCAP::CloudController::App.find(guid: parsed_response['guid'])
        expect(process.type).to eq(type)
      end
    end

    context 'with a docker image' do
      let(:buildpack) { nil }
      let(:environment_json) { { 'CF_DIEGO_BETA' => 'true', 'CF_DIEGO_RUN_BETA' => 'true' } }
      let(:docker_image) { 'cloudfoundry/hello' }
      let(:type) { 'worker' }

      example 'Create a Docker Process' do
        expected_response = {
          'guid' => /^[a-z0-9\-]+$/,
          'type' => type,
        }
        expect {
          do_request_with_error_handling
        }.to change { VCAP::CloudController::App.count }.by(1)
        parsed_response = JSON.parse(response_body)

        expect(response_status).to eq(201)
        expect(parsed_response).to match(expected_response)
      end
    end
  end
end
