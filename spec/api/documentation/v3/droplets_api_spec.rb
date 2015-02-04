require 'spec_helper'
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

  get '/v3/droplets/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:guid) { droplet_model.guid }

    let(:package_model) do
      VCAP::CloudController::PackageModel.make(space_guid: space_guid)
    end

    let(:droplet_model) do
      VCAP::CloudController::DropletModel.make(package_guid: package_model.guid)
    end

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'Get a Droplet' do
      expected_response = {
        'guid'              => droplet_model.guid,
        'state'             => droplet_model.state,
        'hash'              => droplet_model.droplet_hash,
        'buildpack_git_url' => droplet_model.buildpack_git_url,
        'created_at'        => droplet_model.created_at.as_json,
        '_links'            => {
          'self'    => { 'href' => "/v3/droplets/#{guid}" },
          'package' => { 'href' => "/v3/packages/#{package_model.guid}" },
        }
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
    end
  end

  get '/v3/droplets' do
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, 'Number of results per page', valid_values: '1-5000'
    let(:space) { VCAP::CloudController::Space.make }
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:package) do
      VCAP::CloudController::PackageModel.make(space_guid: space.guid, type: VCAP::CloudController::PackageModel::BITS_TYPE)
    end

    let!(:droplet1) { VCAP::CloudController::DropletModel.make(package_guid: package.guid, buildpack_guid: buildpack.guid) }
    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        package_guid: package.guid,
        droplet_hash: 'my-hash',
        buildpack_git_url: 'https://github.com/cloudfoundry/my-buildpack.git',
        state: VCAP::CloudController::DropletModel::STAGED_STATE
      )
    end
    let!(:droplet3) { VCAP::CloudController::DropletModel.make(package_guid: VCAP::CloudController::PackageModel.make.guid) }

    let(:page) { 1 }
    let(:per_page) { 2 }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'List all Droplets' do
      expected_response =
        {
          'pagination' => {
            'total_results' => 2,
            'first'         => { 'href' => '/v3/droplets?page=1&per_page=2' },
            'last'          => { 'href' => '/v3/droplets?page=1&per_page=2' },
            'next'          => nil,
            'previous'      => nil,
          },
          'resources'  => [
            {
              'guid'              => droplet1.guid,
              'state'             => VCAP::CloudController::DropletModel::STAGING_STATE,
              'hash'              => nil,
              'buildpack_git_url' => nil,
              'created_at'        => droplet1.created_at.as_json,
              '_links'            => {
                'self'      => { 'href' => "/v3/droplets/#{droplet1.guid}" },
                'package'   => { 'href' => "/v3/packages/#{package.guid}" },
                'buildpack' => { 'href' => "/v2/buildpacks/#{buildpack.guid}" },
              }
            },
            {
              'guid'              => droplet2.guid,
              'state'             => VCAP::CloudController::DropletModel::STAGED_STATE,
              'hash'              => 'my-hash',
              'buildpack_git_url' => 'https://github.com/cloudfoundry/my-buildpack.git',
              'created_at'        => droplet2.created_at.as_json,
              '_links'            => {
                'self'      => { 'href' => "/v3/droplets/#{droplet2.guid}" },
                'package'   => { 'href' => "/v3/packages/#{package.guid}" },
              }
            },
          ]
        }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
    end
  end
end
