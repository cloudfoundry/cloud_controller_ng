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

  # get '/v3/packages/:guid' do
  #   let(:space) { VCAP::CloudController::Space.make }
  #   let(:package_model) do
  #     VCAP::CloudController::PackageModel.make(space_guid: space_guid)
  #   end

  #   let(:guid) { package_model.guid }
  #   let(:space_guid) { space.guid }

  #   before do
  #     space.organization.add_user user
  #     space.add_developer user
  #   end

  #   example 'Get a Package' do
  #     expected_response = {
  #       'type'       => package_model.type,
  #       'guid'       => guid,
  #       'hash'       => nil,
  #       'state'      => VCAP::CloudController::PackageModel::CREATED_STATE,
  #       'url'        => nil,
  #       'error'      => nil,
  #       'created_at' => package_model.created_at.as_json,
  #       '_links'     => {
  #         'self'   => { 'href' => "/v3/packages/#{guid}" },
  #         'upload' => { 'href' => "/v3/packages/#{guid}/upload" },
  #         'app'    => { 'href' => "/v3/apps/#{package_model.app_guid}" },
  #         'space'  => { 'href' => "/v2/spaces/#{space_guid}" },
  #       }
  #     }

  #     do_request_with_error_handling

  #     parsed_response = MultiJson.load(response_body)
  #     expect(response_status).to eq(200)
  #     expect(parsed_response).to match(expected_response)
  #   end
  # end

  # delete '/v3/packages/:guid' do
  #   let(:space) { VCAP::CloudController::Space.make }
  #   let(:space_guid) { space.guid }
  #   let!(:package_model) do
  #     VCAP::CloudController::PackageModel.make(space_guid: space_guid)
  #   end

  #   let(:guid) { package_model.guid }

  #   before do
  #     space.organization.add_user user
  #     space.add_developer user
  #   end

  #   example 'Delete a Package' do
  #     expect {
  #       do_request_with_error_handling
  #     }.to change { VCAP::CloudController::PackageModel.count }.by(-1)
  #     expect(response_status).to eq(204)
  #   end
  # end
end

def stub_schedule_sync(&before_resolve)
  allow(EM).to receive(:schedule_sync) do |&blk|
    promise = VCAP::Concurrency::Promise.new

    begin
      if blk.arity > 0
        blk.call(promise)
      else
        promise.deliver(blk.call)
      end
    rescue => e
      promise.fail(e)
    end

    # Call before_resolve block before trying to resolve the promise
    before_resolve.call

    promise.resolve
  end
end
