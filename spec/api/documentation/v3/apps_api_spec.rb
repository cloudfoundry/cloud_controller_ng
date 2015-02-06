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

  get '/v3/apps' do
    parameter :names, 'Names of apps to filter by', valid_values: 'array of strings', example_values: 'names[]=name1&names[]=name2'
    parameter :space_guids, 'Spaces to filter by', valid_values: 'array of strings', example_values: 'space_guids[]=space_guid1&space_guids[]=space_guid2'
    parameter :organization_guids, 'Organizations to filter by', valid_values: 'array of strings', example_values: 'organization_guids[]=org_guid1&organization_guids[]=org_guid2'
    parameter :guids, 'App guids to filter by', valid_values: 'array of strings', example_values: 'guid[]=guid1&guid[]=guid2'
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, "Number of results per page", valid_values: '1 - 5000'

    let(:name1) { 'my_app1' }
    let(:name2) { 'my_app2' }
    let(:name3) { 'my_app3' }
    let!(:app_model1) { VCAP::CloudController::AppModel.make(name: name1, space_guid: space.guid) }
    let!(:app_model2) { VCAP::CloudController::AppModel.make(name: name2, space_guid: space.guid) }
    let!(:app_model3) { VCAP::CloudController::AppModel.make(name: name3, space_guid: space.guid) }
    let!(:app_model4) { VCAP::CloudController::AppModel.make(space_guid: VCAP::CloudController::Space.make.guid) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:page) { 1 }
    let(:per_page) { 2 }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'List all Apps' do
      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'first'         => { 'href' => '/v3/apps?page=1&per_page=2' },
          'last'          => { 'href' => '/v3/apps?page=2&per_page=2' },
          'next'          => { 'href' => '/v3/apps?page=2&per_page=2' },
          'previous'      => nil,
        },
        'resources'  => [
          {
            'name'   => name1,
            'guid'   => app_model1.guid,
            '_links' => {
              'self'      => { 'href' => "/v3/apps/#{app_model1.guid}" },
              'processes' => { 'href' => "/v3/apps/#{app_model1.guid}/processes" },
              'packages'  => { 'href' => "/v3/apps/#{app_model1.guid}/packages" },
              'space'     => { 'href' => "/v2/spaces/#{space.guid}" },
            }
          },
          {
            'name'   => name2,
            'guid'   => app_model2.guid,
            '_links' => {
              'self'      => { 'href' => "/v3/apps/#{app_model2.guid}" },
              'processes' => { 'href' => "/v3/apps/#{app_model2.guid}/processes" },
              'packages'  => { 'href' => "/v3/apps/#{app_model2.guid}/packages" },
              'space'     => { 'href' => "/v2/spaces/#{space.guid}" },
            }
          }
        ]
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
    end

    context 'faceted search' do
      let(:app_model5) { VCAP::CloudController::AppModel.make(name: name1, space_guid: VCAP::CloudController::Space.make.guid) }
      let!(:app_model6) { VCAP::CloudController::AppModel.make(name: name1, space_guid: VCAP::CloudController::Space.make.guid) }
      let(:space_guids) { [app_model5.space_guid, space.guid, app_model6.space_guid] }
      let(:per_page) { 2 }
      let(:names) { [name1] }
      def space_guid_facets(space_guids)
        space_guids.map { |sg| "space_guids[]=#{sg}" }.join('&')
      end
      example 'Filters apps by name and spaces and guids and orgs' do
        user.admin = true
        user.save
        expected_pagination = {
          'total_results' => 3,
          'first'         => { 'href' => "/v3/apps?names[]=#{name1}&#{space_guid_facets(space_guids)}&page=1&per_page=2" },
          'last'          => { 'href' => "/v3/apps?names[]=#{name1}&#{space_guid_facets(space_guids)}&page=2&per_page=2" },
          'next'          => { 'href' => "/v3/apps?names[]=#{name1}&#{space_guid_facets(space_guids)}&page=2&per_page=2" },
          'previous'      => nil,
        }

        do_request_with_error_handling

        parsed_response = MultiJson.load(response_body)
        expect(response_status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to eq(['my_app1', 'my_app1'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end
  end

  get '/v3/apps/:guid' do
    let(:app_model) { VCAP::CloudController::AppModel.make(name: name) }
    let(:guid) { app_model.guid }
    let(:space_guid) { app_model.space_guid }
    let(:space) { VCAP::CloudController::Space.find(guid: space_guid) }
    let(:name) { 'my_app' }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'Get an App' do
      expected_response = {
        'name'   => name,
        'guid'   => guid,
        '_links' => {
          'self'      => { 'href' => "/v3/apps/#{guid}" },
          'processes' => { 'href' => "/v3/apps/#{guid}/processes" },
          'packages'  => { 'href' => "/v3/apps/#{guid}/packages" },
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
    let(:name) { 'my_app' }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    parameter :name, 'Name of the App', required: true
    parameter :space_guid, 'GUID of associated Space', required: true

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'Create an App' do
      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::AppModel.count }.by(1)

      expected_guid     = VCAP::CloudController::AppModel.last.guid
      expected_response = {
        'name'   => name,
        'guid'   => expected_guid,
        '_links' => {
          'self'      => { 'href' => "/v3/apps/#{expected_guid}" },
          'processes' => { 'href' => "/v3/apps/#{expected_guid}/processes" },
          'packages'  => { 'href' => "/v3/apps/#{expected_guid}/packages" },
          'space'     => { 'href' => "/v2/spaces/#{space_guid}" },
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(201)
      expect(parsed_response).to match(expected_response)
    end
  end

  patch '/v3/apps/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'original_name', space_guid: space_guid) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    parameter :name, 'Name of the App'

    let(:name) { 'new_name' }
    let(:guid) { app_model.guid }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'Updating an App' do
      do_request_with_error_handling

      expected_response = {
        'name'   => name,
        'guid'   => app_model.guid,
        '_links' => {
          'self'      => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes' => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'  => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'     => { 'href' => "/v2/spaces/#{space_guid}" },
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
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
      }.to change { VCAP::CloudController::AppModel.count }.by(-1)
      expect(response_status).to eq(204)
    end
  end
end
