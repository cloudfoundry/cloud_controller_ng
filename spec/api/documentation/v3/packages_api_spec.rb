require 'spec_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Packages (Experimental)', type: :api do
  let(:iso8601) { /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.freeze }
  let(:tmpdir) { Dir.mktmpdir }
  let(:valid_zip) {
    zip_name = File.join(tmpdir, 'file.zip')
    TestZip.create(zip_name, 1, 1024)
    File.new(zip_name)
  }

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

  get '/v3/packages' do
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, 'Number of results per page', valid_values: '1-5000'

    let(:type1) { 'bits' }
    let(:type2) { 'docker' }
    let(:type3) { 'docker' }
    let!(:package1) { VCAP::CloudController::PackageModel.make(type: type1, app_guid: app_model.guid) }
    let!(:package2) do
      VCAP::CloudController::PackageModel.make(type: type2, app_guid: app_model.guid,
                                               state:                                       VCAP::CloudController::PackageModel::READY_STATE,
                                               url:                                         'http://docker-repo/my-image')
    end
    let!(:package3) { VCAP::CloudController::PackageModel.make(type: type3, app_guid: app_model.guid) }
    let!(:package4) { VCAP::CloudController::PackageModel.make(app_guid: VCAP::CloudController::AppModel.make.guid) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:page) { 1 }
    let(:per_page) { 2 }

    let(:space_guid) { space.guid }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'List all Packages' do
      expected_response =
        {
          'pagination' => {
            'total_results' => 3,
            'first'         => { 'href' => '/v3/packages?page=1&per_page=2' },
            'last'          => { 'href' => '/v3/packages?page=2&per_page=2' },
            'next'          => { 'href' => '/v3/packages?page=2&per_page=2' },
            'previous'      => nil,
          },
          'resources'  => [
            {
              'guid'       => package1.guid,
              'type'       => 'bits',
              'hash'       => { 'type' => 'sha1', 'value' => nil },
              'url'        => nil,
              'state'      => VCAP::CloudController::PackageModel::CREATED_STATE,
              'error'      => nil,
              'created_at' => iso8601,
              'updated_at' => nil,
              '_links'     => {
                'self'   => { 'href' => "/v3/packages/#{package1.guid}" },
                'upload' => { 'href' => "/v3/packages/#{package1.guid}/upload", 'method' => 'POST' },
                'download' => { 'href' => "/v3/packages/#{package1.guid}/download", 'method' => 'GET' },
                'stage' => { 'href' => "/v3/packages/#{package1.guid}/droplets", 'method' => 'POST' },
                'app'    => { 'href' => "/v3/apps/#{package1.app_guid}" },
              }
            },
            {
              'guid'       => package2.guid,
              'type'       => 'docker',
              'hash'       => { 'type' => 'sha1', 'value' => nil },
              'url'        => 'http://docker-repo/my-image',
              'state'      => VCAP::CloudController::PackageModel::READY_STATE,
              'error'      => nil,
              'created_at' => iso8601,
              'updated_at' => nil,
              '_links'     => {
                'self' => { 'href' => "/v3/packages/#{package2.guid}" },
                'app'  => { 'href' => "/v3/apps/#{package2.app_guid}" },
              }
            }
          ]
        }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  get '/v3/packages/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:package_model) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid)
    end

    let(:guid) { package_model.guid }
    let(:space_guid) { space.guid }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'Get a Package' do
      expected_response = {
        'type'       => package_model.type,
        'guid'       => guid,
        'hash'       => { 'type' => 'sha1', 'value' => nil },
        'state'      => VCAP::CloudController::PackageModel::CREATED_STATE,
        'url'        => nil,
        'error'      => nil,
        'created_at' => iso8601,
        'updated_at' => nil,
        '_links'     => {
          'self'   => { 'href' => "/v3/packages/#{guid}" },
          'upload' => { 'href' => "/v3/packages/#{guid}/upload", 'method' => 'POST' },
          'download' => { 'href' => "/v3/packages/#{guid}/download", 'method' => 'GET' },
          'stage' => { 'href' => "/v3/packages/#{guid}/droplets", 'method' => 'POST' },
          'app'    => { 'href' => "/v3/apps/#{app_model.guid}" },
        }
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  post '/v3/apps/:guid/packages' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space_guid) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    describe 'creating a package' do
      let(:guid) { app_model.guid }
      let(:type) { 'docker' }
      let(:url) { 'docker://cloudfoundry/runtime-ci' }

      let(:raw_post) { body_parameters }

      body_parameter :type, 'Package type', required: true, valid_values: ['bits', 'docker']
      body_parameter :url, 'Url of docker image', required: false

      example 'Create a Package' do
        expect {
          do_request
        }.to change { VCAP::CloudController::PackageModel.count }.by(1)

        package = VCAP::CloudController::PackageModel.last

        expected_response = {
          'guid'       => package.guid,
          'type'       => type,
          'hash'       => { 'type' => 'sha1', 'value' => nil },
          'state'      => 'READY',
          'error'      => nil,
          'url'        => url,
          'created_at' => iso8601,
          'updated_at' => nil,
          '_links'     => {
            'self' => { 'href' => "/v3/packages/#{package.guid}" },
            'app'  => { 'href' => "/v3/apps/#{guid}" },
          }
        }

        parsed_response = MultiJson.load(response_body)
        expect(response_status).to eq(201)
        expect(parsed_response).to be_a_response_like(expected_response)
        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
              type:              'audit.app.add_package',
              actee:             parsed_response['guid'],
              actee_type:        'package',
              actee_name:        '',
              actor:             user.guid,
              actor_type:        'user',
              space_guid:        space.guid,
              organization_guid: space.organization.guid
            })
        expect(event.metadata['request']['app_guid']).to eq(app_model.guid)
      end
    end

    describe 'copying a package' do
      let(:target_app_model) { VCAP::CloudController::AppModel.make(space_guid: space_guid) }
      let!(:original_package) { VCAP::CloudController::PackageModel.make(type: 'url', url: 'http://awesome-sauce.com', app_guid: app_model.guid) }

      parameter :source_package_guid, 'The package to copy from', required: true

      let(:guid) { target_app_model.guid }
      let(:source_package_guid) { original_package.guid }

      example 'Copy a Package' do
        # Using client directly instead of calling do_request to ensure parameter is displayed correctly in docs
        expect {
          client.post "/v3/apps/#{guid}/packages?source_package_guid=#{source_package_guid}", {}, headers
        }.to change { VCAP::CloudController::PackageModel.count }.by(1)

        package = VCAP::CloudController::PackageModel.last

        expected_response = {
          'guid'       => package.guid,
          'type'       => 'url',
          'hash'       => { 'type' => 'sha1', 'value' => nil },
          'state'      => 'READY',
          'error'      => nil,
          'url'        => 'http://awesome-sauce.com',
          'created_at' => iso8601,
          'updated_at' => nil,
          '_links'     => {
            'self' => { 'href' => "/v3/packages/#{package.guid}" },
            'app'  => { 'href' => "/v3/apps/#{guid}" },
          }
        }

        expect(status).to eq(201)
        parsed_response = MultiJson.load(response_body)
        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end
  end

  post '/v3/packages/:guid/upload' do
    let(:type) { 'bits' }
    let!(:package_model) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, type: type)
    end
    let(:space) { VCAP::CloudController::Space.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { package_model.guid }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    parameter :bits, 'A binary zip file containing the package bits', required: true

    let(:packages_params) do
      {
        bits_name: 'application.zip',
        bits_path: "#{tmpdir}/application.zip",
      }
    end

    let(:request_body_example) do
      <<-eos.gsub(/^ */, '')
          Content-type: multipart/form-data, boundary=AaB03x
          --AaB03x
          Content-Disposition: form-data; name="type"

          #{type}
          --AaB03x
          Content-Disposition: form-data; name="bits"; filename="application.zip"
          Content-Type: application/zip
          Content-Length: 123
          Content-Transfer-Encoding: binary

          &lt;&lt;binary artifact bytes&gt;&gt;
          --AaB03x
      eos
    end

    example 'Upload Bits for a Package of type bits' do
      expect { do_request packages_params }.to change { Delayed::Job.count }.by(1)

      job = Delayed::Job.last
      expect(job.handler).to include(package_model.guid)
      expect(job.guid).not_to be_nil

      package_model.reload
      expected_response = {
        'guid'       => guid,
        'type'       => type,
        'hash'       => { 'type' => 'sha1', 'value' => nil },
        'state'      => VCAP::CloudController::PackageModel::PENDING_STATE,
        'url'        => nil,
        'error'      => nil,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        '_links'     => {
          'self'   => { 'href' => "/v3/packages/#{package_model.guid}" },
          'upload' => { 'href' => "/v3/packages/#{package_model.guid}/upload", 'method' => 'POST' },
          'download' => { 'href' => "/v3/packages/#{package_model.guid}/download", 'method' => 'GET' },
          'stage' => { 'href' => "/v3/packages/#{package_model.guid}/droplets", 'method' => 'POST' },
          'app'    => { 'href' => "/v3/apps/#{app_model.guid}" },
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  get '/v3/packages/:guid/download' do
    let!(:package_model) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, type: 'bits')
    end
    let(:space) { VCAP::CloudController::Space.make }
    let(:bits_download_url) { CloudController::DependencyLocator.instance.blobstore_url_generator.package_download_url(package_model) }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { package_model.guid }
    let(:temp_file) do
      file = File.join(Dir.mktmpdir, 'application.zip')
      TestZip.create(file, 1, 1024)
      file
    end
    let(:upload_body) do
      {
        bits_name: 'application.zip',
        bits_path: temp_file,
      }
    end

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      client.post "/v3/packages/#{guid}/upload", upload_body, headers
      Delayed::Worker.new.work_off
    end

    example 'Download the bits for a package' do
      explanation <<-eos
        When using a remote blobstore, such as AWS, the response is a redirect to the actual location of the bits.
        If the client is automatically following redirects, then the OAuth token that was used to communicate with Cloud Controller will be replayed on the new redirect request.
        Some blobstores may reject the request in that case. Clients may need to follow the redirect without including the OAuth token.
      eos

      client.get "/v3/packages/#{guid}", {}, headers
      do_request_with_error_handling

      expect(response_status).to eq(302)
      expect(response_headers['Location']).to eq(bits_download_url)
    end
  end

  delete '/v3/packages/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let!(:package_model) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid)
    end

    let(:guid) { package_model.guid }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'Delete a Package' do
      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::PackageModel.count }.by(-1)
      expect(response_status).to eq(204)
    end
  end

  post '/v3/packages/:guid/droplets' do
    body_parameter :buildpack, 'Buildpack to be used when staging the package.
    Note: If this parameter is not provided, then the buildpack associated with your app will be used as a default',
      valid_values:   ['buildpack name', 'git url'],
      example_values: ['ruby_buildpack', 'https://github.com/cloudfoundry/ruby-buildpack'],
      required: false
    body_parameter :environment_variables, 'Environment variables to use during staging.
    Environment variable names may not start with "VCAP_" or "CF_". "PORT" is not a valid environment variable.',
      example_values: ['{"FEATURE_ENABLED": "true"}'],
      required: false
    body_parameter :stack, 'Stack used to stage package', required: false
    body_parameter :memory_limit, 'Memory limit used to stage package', required: false
    body_parameter :disk_limit, 'Disk limit used to stage package', required: false

    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:buildpack) { 'http://github.com/myorg/awesome-buildpack' }
    let(:custom_env_var_val) { 'hello' }
    let(:environment_variables) { { 'CUSTOM_ENV_VAR' => custom_env_var_val } }

    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:app_guid) { app_model.guid }
    let!(:package_model) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_guid,
        state:    VCAP::CloudController::PackageModel::READY_STATE,
        type:     VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end
    let(:guid) { package_model.guid }

    let(:raw_post) { body_parameters }

    let(:stager_id) { 'abc123' }
    let(:stager_subject) { "staging.#{stager_id}.start" }
    let(:stack) { 'cflinuxfs2' }
    let(:advertisment) do
      {
        'id'               => stager_id,
        'stacks'           => [stack],
        'available_memory' => 2048,
        'app_id_to_count'  => {},
      }
    end
    let(:message_bus) { VCAP::CloudController::Config.message_bus }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      allow(EM).to receive(:add_timer)
      allow(EM).to receive(:defer).and_yield
      allow(EM).to receive(:schedule_sync) do |&blk|
        blk.call
      end
    end

    example 'Stage a package' do
      stub_const('SecureRandom', double(:sr, uuid: 'whatuuid', hex: '8-octetx'))
      VCAP::CloudController::Dea::Client.dea_pool.register_subscriptions
      message_bus.publish('dea.advertise', advertisment)
      message_bus.publish('staging.advertise', advertisment)

      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::DropletModel.count }.by(1)

      droplet           = VCAP::CloudController::DropletModel.last
      expected_response = {
        'guid'                   => droplet.guid,
        'state'                  => 'PENDING',
        'hash'                   => { 'type' => 'sha1', 'value' => nil },
        'buildpack'              => 'http://github.com/myorg/awesome-buildpack',
        'error'                  => nil,
        'procfile'               => nil,
        'created_at'             => iso8601,
        'updated_at'             => nil,
        'environment_variables'  => {
          'CF_STACK' => stack,
          'CUSTOM_ENV_VAR' => custom_env_var_val,
          'VCAP_APPLICATION' => {
            'limits' => { 'mem' => 1024, 'disk' => 4096, 'fds' => 16384 },
            'application_id' => app_guid,
            'application_version' => 'whatuuid',
            'application_name' => app_model.name, 'application_uris' => [],
            'version' => 'whatuuid',
            'name' => app_model.name,
            'space_name' => space.name,
            'space_id' => space.guid,
            'uris' => [],
            'users' => nil
          }
        },
        '_links'                 => {
          'self'    => { 'href' => "/v3/droplets/#{droplet.guid}" },
          'package' => { 'href' => "/v3/packages/#{guid}" },
          'app'     => { 'href' => "/v3/apps/#{app_guid}" }
        }
      }

      expect(response_status).to eq(201)

      parsed_response = MultiJson.load(response_body)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
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
