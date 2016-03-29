require 'rails_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Droplets (Experimental)', type: :api do
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

  delete '/v3/droplets/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:guid) { droplet_model.guid }

    let(:app_model) do
      VCAP::CloudController::AppModel.make(space_guid: space_guid)
    end

    let!(:droplet_model) do
      VCAP::CloudController::DropletModel.make(:buildpack, app_guid: app_model.guid)
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

  get '/v3/apps/:guid/droplets' do
    parameter :states, 'Droplet state to filter by', valid_values: %w(PENDING STAGING STAGED FAILED EXPIRED), example_values: 'states=PENDING,STAGING'
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
        :buildpack,
        app_guid:                         app_model.guid,
        created_at:                       Time.at(1),
        package_guid:                     package.guid,
        buildpack_receipt_buildpack:      buildpack.name,
        buildpack_receipt_buildpack_guid: buildpack.guid,
        environment_variables:            { 'yuu' => 'huuu' },
        memory_limit:                     123,
      )
    end
    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        :buildpack,
        app_guid:                    app_model.guid,
        created_at:                  Time.at(2),
        package_guid:                package.guid,
        droplet_hash:                'my-hash',
        buildpack_receipt_buildpack: 'https://github.com/cloudfoundry/my-buildpack.git',
        process_types:               { web: 'started' }.to_json,
        state:                       VCAP::CloudController::DropletModel::STAGED_STATE,
        memory_limit:                123,
      )
    end
    let!(:droplet3) { VCAP::CloudController::DropletModel.make(:buildpack, package_guid: VCAP::CloudController::PackageModel.make.guid) }

    let(:guid) { app_model.guid }
    let(:page) { 1 }
    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(droplet: droplet1)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(droplet: droplet2)
    end

    it 'List associated droplets' do
      expected_response =
        {
          'pagination' => {
            'total_results' => 2,
            'first'         => { 'href' => "/v3/apps/#{guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
            'last'          => { 'href' => "/v3/apps/#{guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
            'next'          => nil,
            'previous'      => nil,
          },
          'resources' => [
            {
              'guid'                   => droplet2.guid,
              'state'                  => VCAP::CloudController::DropletModel::STAGED_STATE,
              'error'                  => droplet2.error,
              'lifecycle'              => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => droplet2.lifecycle_data.buildpack,
                  'stack' => droplet2.lifecycle_data.stack,
                }
              },
              'memory_limit' => 123,
              'disk_limit' => nil,
              'environment_variables' => {},
              'result'                   => {
                'hash'                   => { 'type' => 'sha1', 'value' => 'my-hash' },
                'process_types'          => droplet2.process_types,
                'buildpack'              => 'https://github.com/cloudfoundry/my-buildpack.git',
                'execution_metadata'     => nil,
                'stack'                  => nil
              },
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
              'error'                  => droplet1.error,
              'lifecycle'              => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => droplet1.lifecycle_data.buildpack,
                  'stack' => droplet1.lifecycle_data.stack,
                }
              },
              'memory_limit' => 123,
              'disk_limit' => nil,
              'environment_variables' => droplet1.environment_variables,
              'result' => nil,
              'created_at'             => iso8601,
              'updated_at'             => iso8601,
              'links' => {
                'self'      => { 'href' => "/v3/droplets/#{droplet1.guid}" },
                'package'   => { 'href' => "/v3/packages/#{package.guid}" },
                'buildpack' => { 'href' => "/v2/buildpacks/#{buildpack.guid}" },
                'app'       => { 'href' => "/v3/apps/#{droplet1.app_guid}" },
                'assign_current_droplet' => {
                  'href' => "/v3/apps/#{droplet1.app_guid}/current_droplet",
                  'method' => 'PUT'
                }
              }
            }
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
          :buildpack,
          app_guid: app_model.guid,
          created_at: Time.at(2),
          package_guid: package.guid,
          droplet_hash: 'my-hash',
          buildpack_receipt_buildpack: 'https://github.com/cloudfoundry/my-buildpack.git',
          state: VCAP::CloudController::DropletModel::FAILED_STATE
        )
      end
      let(:per_page) { 2 }
      let(:states) { [VCAP::CloudController::DropletModel::STAGED_STATE, VCAP::CloudController::DropletModel::FAILED_STATE].join(',') }

      it 'Filters Droplets by states' do
        VCAP::CloudController::BuildpackLifecycleDataModel.make(droplet: droplet4)
        user.admin = true
        user.save

        expected_states = "#{VCAP::CloudController::DropletModel::STAGED_STATE},#{VCAP::CloudController::DropletModel::FAILED_STATE}"
        expected_pagination = {
          'total_results' => 2,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2&states=#{CGI.escape(expected_states)}" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2&states=#{CGI.escape(expected_states)}" },
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
