require 'spec_helper'
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

  get '/v3/apps/:guid/routes' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }

    let!(:route1) { VCAP::CloudController::Route.make(space_guid: space_guid) }
    let!(:route2) { VCAP::CloudController::Route.make(space_guid: space_guid, path: '/foo/bar') }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { app_model.guid }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      VCAP::CloudController::AddRouteToApp.new(nil, nil).add(app_model, route1, nil)
      VCAP::CloudController::AddRouteToApp.new(nil, nil).add(app_model, route2, nil)
    end

    example 'List routes' do
      do_request_with_error_handling
      expected_response = {
        'pagination' => {
          'total_results' => 2,
          'first'         => { 'href' => "/v3/apps/#{guid}/routes?page=1&per_page=50" },
          'last'          => { 'href' => "/v3/apps/#{guid}/routes?page=1&per_page=50" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'       => route1.guid,
            'host'       => route1.host,
            'created_at' => iso8601,
            'updated_at' => nil,
            '_links' => {
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
              'domain' => { 'href' => "/v2/domains/#{route1.domain.guid}" }
            }
          },
          {
            'guid'       => route2.guid,
            'host'       => route2.host,
            'path'       => '/foo/bar',
            'created_at' => iso8601,
            'updated_at' => nil,
            '_links' => {
              'space' => { 'href' => "/v2/spaces/#{space.guid}" },
              'domain' => { 'href' => "/v2/domains/#{route2.domain.guid}" }
            }
          },
        ]
      }
      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  delete '/v3/apps/:guid/routes' do
    parameter :route_guid, 'GUID of the route', required: true

    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }

    let(:route1) { VCAP::CloudController::Route.make(space_guid: space_guid) }
    let(:route2) { VCAP::CloudController::Route.make(space_guid: space_guid) }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:web_process) { VCAP::CloudController::AppFactory.make(space_guid: space_guid, type: 'web') }
    let(:guid) { app_model.guid }

    let(:route_guid) { route1.guid }
    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)

      app_model.add_process(web_process)

      VCAP::CloudController::AddRouteToApp.new(nil, nil).add(app_model, route1, web_process)
      VCAP::CloudController::AddRouteToApp.new(nil, nil).add(app_model, route2, web_process)
    end

    example 'Unmap a Route' do
      do_request_with_error_handling
      expect(response_status).to eq(204)

      app_model.refresh
      web_process.refresh
      expect(app_model.routes).to eq([route2])
      expect(web_process.routes).to eq([route2])
    end
  end
end
