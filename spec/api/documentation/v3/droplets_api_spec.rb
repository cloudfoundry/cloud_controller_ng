require 'rails_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Droplets (Experimental)', type: :api do
  let(:iso8601) { /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.freeze }
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

  get '/v3/droplets/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:guid) { droplet_model.guid }
    let(:buildpack_git_url) { 'http://buildpack.git.url.com' }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }

    let!(:droplet_model) do
      VCAP::CloudController::DropletModel.make(
        state:                  VCAP::CloudController::DropletModel::STAGED_STATE,
        app_guid:               app_model.guid,
        package_guid:           package_model.guid,
        buildpack:              buildpack_git_url,
        error:                  'example error',
        environment_variables:  { 'cloud' => 'foundry' },
      )
    end

    let(:app_guid) { droplet_model.app_guid }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'Get a Droplet' do
      expected_response = {
        'guid'                   => droplet_model.guid,
        'state'                  => droplet_model.state,
        'error'                  => droplet_model.error,
        'lifecycle'              => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => droplet_model.lifecycle_data.buildpack,
            'stack' => droplet_model.lifecycle_data.stack,
          }
        },
        'result' => {
          'hash'                 => { 'type' => 'sha1', 'value' => droplet_model.droplet_hash },
          'stack'                => droplet_model.stack_name,
          'process_types'        => droplet_model.process_types,
          'execution_metadata'   => droplet_model.execution_metadata,
          'buildpack'            => droplet_model.buildpack
        },
        'memory_limit'           => droplet_model.memory_limit,
        'disk_limit'             => droplet_model.disk_limit,
        'detected_start_command' => droplet_model.detected_start_command,
        'environment_variables'  => droplet_model.environment_variables,
        'created_at'             => iso8601,
        'updated_at'             => iso8601,
        'links'                 => {
          'self'    => { 'href' => "/v3/droplets/#{guid}" },
          'package' => { 'href' => "/v3/packages/#{package_model.guid}" },
          'app'     => { 'href' => "/v3/apps/#{app_guid}" },
          'assign_current_droplet' => {
            'href' => "/v3/apps/#{app_guid}/current_droplet",
            'method' => 'PUT'
          }
        }
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  delete '/v3/droplets/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:guid) { droplet_model.guid }

    let(:app_model) do
      VCAP::CloudController::AppModel.make(space_guid: space_guid)
    end

    let!(:droplet_model) do
      VCAP::CloudController::DropletModel.make(app_guid: app_model.guid)
    end

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'Delete a Droplet' do
      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::DropletModel.count }.by(-1)
      expect(response_status).to eq(204)
      expect(VCAP::CloudController::DropletModel.find(guid: guid)).to be_nil
    end
  end

  get '/v3/droplets' do
    parameter :app_guids, 'Apps to filter by', valid_values: 'app guids', example_values: 'app_guids=app_guid1,app_guid2'
    parameter :states, 'Droplet state to filter by', valid_values: %w(PENDING STAGING STAGED FAILED), example_values: 'states=PENDING,STAGING'
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, 'Number of results per page', valid_values: '1-5000'
    parameter :order_by, 'Value to sort by. Prepend with "+" or "-" to change sort direction to ascending or descending, respectively.', valid_values: %w(created_at updated_at)

    let(:space) { VCAP::CloudController::Space.make }
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:package) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        type: VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end

    let!(:droplet1) do
      VCAP::CloudController::DropletModel.make(
        app_guid:              app_model.guid,
        created_at:            Time.at(1),
        package_guid:          package.guid,
        buildpack:             buildpack.name,
        buildpack_guid:        buildpack.guid,
        environment_variables: { 'yuu' => 'huuu' }
      )
    end
    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        app_guid:     app_model.guid,
        created_at: Time.at(2),
        package_guid: package.guid,
        droplet_hash: 'my-hash',
        buildpack:    'https://github.com/cloudfoundry/detected-buildpack.git',
        state:        VCAP::CloudController::DropletModel::STAGED_STATE,
        process_types: { 'web' => 'started' },
        memory_limit: 123,
        disk_limit: 456,
        execution_metadata: 'black-box-secrets'

      )
    end
    let!(:droplet3) { VCAP::CloudController::DropletModel.make(package_guid: VCAP::CloudController::PackageModel.make.guid) }

    let(:page) { 1 }
    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      space.organization.add_user user
      space.add_developer user
      VCAP::CloudController::BuildpackLifecycleDataModel.make(droplet: droplet2)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(droplet: droplet1)
    end

    example 'List all Droplets' do
      expected_response =
        {
          'pagination' => {
            'total_results' => 2,
            'first'         => { 'href' => "/v3/droplets?order_by=#{order_by}&page=1&per_page=2" },
            'last'          => { 'href' => "/v3/droplets?order_by=#{order_by}&page=1&per_page=2" },
            'next'          => nil,
            'previous'      => nil,
          },
          'resources'  => [
            {
              'guid'                   => droplet2.guid,
              'state'                  => VCAP::CloudController::DropletModel::STAGED_STATE,
              'lifecycle'              => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => droplet2.lifecycle_data.buildpack,
                  'stack' => droplet2.lifecycle_data.stack,
                }
              },
              'error'                  => droplet2.error,
              'memory_limit'           => droplet2.memory_limit,
              'disk_limit'             => droplet2.disk_limit,
              'result'                 => {
                'hash'                 => { 'type' => 'sha1', 'value' => 'my-hash' },
                'buildpack'            =>  'https://github.com/cloudfoundry/detected-buildpack.git',
                'stack'                => nil,
                'process_types'        => { 'web' => 'started' },
                'execution_metadata'   => 'black-box-secrets'
              },
              'environment_variables'  => {},
              'created_at'             => iso8601,
              'updated_at'             => iso8601,
              'links'                 => {
                'self'    => { 'href' => "/v3/droplets/#{droplet2.guid}" },
                'package' => { 'href' => "/v3/packages/#{package.guid}" },
                'app'     => { 'href' => "/v3/apps/#{droplet2.app_guid}" },
                'assign_current_droplet' => {
                  'href' => "/v3/apps/#{droplet2.app_guid}/current_droplet",
                  'method' => 'PUT'
                }
              }
            },
            {
              'guid'                   => droplet1.guid,
              'state'                  => VCAP::CloudController::DropletModel::STAGING_STATE,
              'lifecycle'              => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => droplet1.lifecycle_data.buildpack,
                  'stack' => droplet1.lifecycle_data.stack,
                }
              },
              'error'                  => droplet1.error,
              'memory_limit'           => droplet1.memory_limit,
              'disk_limit'             => droplet1.disk_limit,
              'result'                 => {
                'hash'                 => { 'type' => 'sha1', 'value' => nil },
                'buildpack'            =>  droplet1.buildpack,
                'stack'                => nil,
                'process_types'        => nil,
                'execution_metadata'   => nil,
              },
              'environment_variables'  => droplet1.environment_variables,
              'created_at'             => iso8601,
              'updated_at'             => iso8601,
              'links'                 => {
                'self'      => { 'href' => "/v3/droplets/#{droplet1.guid}" },
                'package'   => { 'href' => "/v3/packages/#{package.guid}" },
                'buildpack' => { 'href' => "/v2/buildpacks/#{buildpack.guid}" },
                'app'       => { 'href' => "/v3/apps/#{droplet1.app_guid}" },
                'assign_current_droplet' => {
                  'href' => "/v3/apps/#{droplet1.app_guid}/current_droplet",
                  'method' => 'PUT'
                }
              }
            },
          ]
        }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'faceted search' do
      let!(:droplet4) do
        VCAP::CloudController::DropletModel.make(
          app_guid:     app_model.guid,
          created_at: Time.at(2),
          package_guid: package.guid,
          droplet_hash: 'my-hash',
          buildpack:    'https://github.com/cloudfoundry/my-buildpack.git',
          state:        VCAP::CloudController::DropletModel::FAILED_STATE
        )
      end
      let(:per_page) { 2 }
      let(:app_guids) { [app_model.guid].join(',') }
      let(:states) { [VCAP::CloudController::DropletModel::STAGED_STATE, VCAP::CloudController::DropletModel::FAILED_STATE].join(',') }

      before do
        VCAP::CloudController::BuildpackLifecycleDataModel.make(droplet: droplet4)
      end

      it 'Filters Droplets by states, app_guids' do
        user.admin = true
        user.save

        expected_states = "#{VCAP::CloudController::DropletModel::STAGED_STATE},#{VCAP::CloudController::DropletModel::FAILED_STATE}"
        expected_pagination = {
          'total_results' => 2,
          'first'         => { 'href' => "/v3/droplets?app_guids=#{app_model.guid}&order_by=#{order_by}&page=1&per_page=2&states=#{CGI.escape(expected_states)}" },
          'last'          => { 'href' => "/v3/droplets?app_guids=#{app_model.guid}&order_by=#{order_by}&page=1&per_page=2&states=#{CGI.escape(expected_states)}" },
          'next'          => nil,
          'previous'      => nil
        }

        do_request_with_error_handling

        parsed_response = MultiJson.load(response_body)
        expect(response_status).to eq(200)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end
  end
end
