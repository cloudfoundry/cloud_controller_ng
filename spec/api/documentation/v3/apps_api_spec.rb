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

  get '/v3/apps/:guid' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:guid) { app_model.guid }
    let(:space_guid) { app_model.space_guid }
    let(:space) { VCAP::CloudController::Space.find(guid: space_guid) }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'Get an App' do
      process = VCAP::CloudController::AppFactory.make(app_guid: guid)
      expected_response = {
        'guid'   => guid,
        '_links' => {
          'self'      => { 'href' => "/v3/apps/#{guid}" },
          'processes' => [
            { 'href' => "/v3/processes/#{process.guid}" },
          ],
          'space'     => { 'href' => "/v2/spaces/#{space_guid}" },
        }
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
    end
  end

  post '/v3/apps' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    parameter :space_guid, 'GUID of associated Space', required: true

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'Create an App' do
      expect {
        do_request_with_error_handling
      }.to change{ VCAP::CloudController::AppModel.count }.by(1)

      expected_guid = VCAP::CloudController::AppModel.last.guid
      expected_response = {
        'guid'   => expected_guid,
        '_links' => {
          'self'      => { 'href' => "/v3/apps/#{expected_guid}" },
          'processes' => [],
          'space'     => { 'href' => "/v2/spaces/#{space_guid}" },
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(201)
      expect(parsed_response).to match(expected_response)
    end
  end

  post '/v3/apps/:guid/processes' do
    let(:stack) { VCAP::CloudController::Stack.make }
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:guid) { app_model.guid }
    let(:space_guid) { app_model.space_guid }
    let(:space) { VCAP::CloudController::Space.find(guid: space_guid) }
    let(:name) { 'process' }
    let(:memory) { 256 }
    let(:instances) { 2 }
    let(:disk_quota) { 1024 }
    let(:stack_guid) { stack.guid }

    parameter :name, 'Name of process', required: true
    parameter :memory, 'Amount of memory (MB) allocated to each instance', required: true
    parameter :instances, 'Number of instances', required: true
    parameter :disk_quota, 'Amount of disk space (MB) allocated to each instance', required: true
    parameter :space_guid, 'Guid of associated Space', required: true
    parameter :stack_guid, 'Guid of associated Stack', required: true
    parameter :state, 'Desired state of process'
    parameter :command, 'Start command for process'
    parameter :buildpack, 'Buildpack used to stage process'
    parameter :health_check_timeout, 'Health check timeout for process'
    parameter :docker_image, 'Name of docker image containing process'
    parameter :environment_json, 'JSON key-value pairs for ENV variables'

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    context 'without a docker image' do
      example 'Create a Process' do
        expected_response = {
          'guid' => /^[a-z0-9\-]+$/,
        }
        expect {
          do_request_with_error_handling
          expect(response_status).to eq(201)
        }.to change{ app_model.reload.processes.count }.by(1)
        parsed_response = JSON.parse(response_body)

        expect(parsed_response).to match(expected_response)
        expect(app_model.processes.first.name).to eq(name)
      end
    end

    context 'with a docker image' do
      let(:environment_json) { { 'CF_DIEGO_BETA' => 'true', 'CF_DIEGO_RUN_BETA' => 'true' } }
      let(:docker_image) { 'cloudfoundry/hello' }

      example 'Create a Docker Process' do
        expected_response = {
          'guid' => /^[a-z0-9\-]+$/,
        }
        expect {
          do_request_with_error_handling
          expect(response_status).to eq(201)
        }.to change{ app_model.reload.processes.count }.by(1)
        parsed_response = JSON.parse(response_body)

        expect(parsed_response).to match(expected_response)
        expect(app_model.processes.first.name).to eq(name)
      end
    end
  end

  delete '/v3/apps/:guid' do
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let(:guid) { app_model.guid }
    let(:space_guid) { app_model.space_guid }
    let(:space) { VCAP::CloudController::Space.find(guid: space_guid) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    example 'Delete an App' do
      expect {
        do_request_with_error_handling
      }.to change{ VCAP::CloudController::AppModel.count }.by(-1)
      expect(response_status).to eq(204)
    end
  end
end
