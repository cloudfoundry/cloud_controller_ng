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
