require 'spec_helper'
require 'actions/v2/app_create'

module VCAP::CloudController
  RSpec.describe V2::AppCreate do
    let(:space) { Space.make }
    let(:access_validator) { double('access_validator', validate_access: true) }
    subject(:app_create) { V2::AppCreate.new(access_validator: access_validator) }

    describe 'create' do
      let(:request_attrs) do
        {
          'name'              => 'maria',
          'space_guid'        => space.guid,
          'environment_json'  => { 'KEY' => 'val' },
          'buildpack'         => 'http://example.com/buildpack',
          'state'             => 'STOPPED',
          'health_check_type' => 'port',
          'enable_ssh' => 'false',
          'stack_guid' => stack.guid,
        }
      end

      let(:stack) { Stack.make(name: 'stacks-on-stacks') }

      it 'creates the app' do
        process = app_create.create(request_attrs)

        expect(process.name).to eq('maria')
        expect(process.space).to eq(space)
        expect(process.environment_json).to eq({ 'KEY' => 'val' })
        expect(process.stack).to eq(stack)
        expect(process.custom_buildpack_url).to eq('http://example.com/buildpack')

        v3_app = process.app
        expect(v3_app.name).to eq('maria')
        expect(v3_app.space).to eq(space)
        expect(v3_app.environment_variables).to eq({ 'KEY' => 'val' })
        expect(v3_app.lifecycle_type).to eq(BuildpackLifecycleDataModel::LIFECYCLE_TYPE)
        expect(v3_app.lifecycle_data.stack).to eq('stacks-on-stacks')
        expect(v3_app.lifecycle_data.buildpacks).to eq(['http://example.com/buildpack'])
        expect(v3_app.desired_state).to eq(process.state)
        expect(v3_app.enable_ssh).to be false

        expect(v3_app.guid).to eq(process.guid)
      end

      context 'when the health_check_type is http' do
        let(:request_attrs) do
          {
            'name'                       => 'maria',
            'space_guid'                 => space.guid,
            'environment_json'           => { 'KEY' => 'val' },
            'buildpack'                  => 'http://example.com/buildpack',
            'state'                      => 'STOPPED',
            'health_check_type'          => 'http',
            'health_check_http_endpoint' => '/healthz',
            'stack_guid'                 => stack.guid
          }
        end

        it 'creates the app' do
          process = app_create.create(request_attrs)

          expect(process.health_check_type).to eq('http')
          expect(process.health_check_http_endpoint).to eq('/healthz')
        end
      end

      context 'when custom buildpacks are disabled' do
        before { TestConfig.override(disable_custom_buildpacks: true) }

        let(:request_attrs) do
          {
            'name'              => 'maria',
            'space_guid'        => space.guid,
            'state'             => 'STOPPED',
            'health_check_type' => 'port'
          }
        end

        it 'does NOT allow a public git url' do
          request_attrs['buildpack'] = 'http://example.com/buildpack'
          expect { app_create.create(request_attrs) }.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
        end

        it 'does NOT allow a public http url' do
          request_attrs['buildpack'] = 'http://example.com/foo'
          expect { app_create.create(request_attrs) }.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
        end

        it 'does allow a buildpack name' do
          admin_buildpack            = Buildpack.make
          request_attrs['buildpack'] = admin_buildpack.name
          expect { app_create.create(request_attrs) }.not_to raise_error
        end

        it 'does not allow a private git url' do
          request_attrs['buildpack'] = 'git@example.com:foo.git'
          expect { app_create.create(request_attrs) }.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
        end

        it 'does not allow a private git url with ssh schema' do
          request_attrs['buildpack'] = 'ssh://git@example.com:foo.git'
          expect { app_create.create(request_attrs) }.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
        end
      end

      context 'when the app is based on a docker image' do
        let(:request_attrs) do
          {
            'name'              => 'maria',
            'space_guid'        => space.guid,
            'state'             => 'STOPPED',
            'health_check_type' => 'port',
            'docker_image'      => 'some-image:latest',
          }
        end

        it 'creates docker apps correctly' do
          process = app_create.create(request_attrs)

          expect(process.docker_image).to eq('some-image:latest')
          expect(process.package_hash).to eq('some-image:latest')

          package = process.latest_package
          expect(package.image).to eq('some-image:latest')
        end
      end

      context 'when docker credentials are specified' do
        let(:request_attrs) do
          {
            'name'               => 'maria',
            'space_guid'         => space.guid,
            'state'              => 'STOPPED',
            'health_check_type'  => 'port',
            'docker_credentials' => {
              'username' => 'username',
              'password' => 'password'
            }
          }
        end

        context 'when a docker image is specified' do
          it 'creates the app with docker credentials' do
            request_attrs['docker_image'] = 'some-image:latest'

            process = app_create.create(request_attrs)

            expect(process.docker_image).to eq('some-image:latest')
            expect(process.docker_username).to eq('username')
            expect(process.docker_password).to eq('password')
            expect(process.package_hash).to eq('some-image:latest')

            package = process.latest_package
            expect(package.image).to eq('some-image:latest')
            expect(package.docker_username).to eq('username')
            expect(package.docker_password).to eq('password')
          end
        end

        context 'when no docker image is specified' do
          it 'returns an error' do
            expect { app_create.create(request_attrs) }.to raise_error(CloudController::Errors::ApiError,
              /Docker credentials can only be supplied for apps with a 'docker_image'/)
          end
        end
      end

      context 'when starting an app without a package' do
        let(:request_attrs) do
          {
            'name'              => 'maria',
            'space_guid'        => space.guid,
            'state'             => 'STARTED',
            'health_check_type' => 'port',
          }
        end

        it 'raises an error' do
          expect { app_create.create(request_attrs) }.to raise_error(/bits have not been uploaded/)
        end
      end

      context 'when the nil buildpack is specified' do
        let(:request_attrs) do
          {
            'name'       => 'maria',
            'space_guid' => space.guid,
            'buildpack'  => nil,
            'state'      => 'STOPPED',
            'health_check_type' => 'port',
          }
        end

        it 'creates the app' do
          process = app_create.create(request_attrs)
          expect(process.app.lifecycle_data.buildpacks).to eq([])
        end
      end

      context 'when the blank buildpack is specified' do
        let(:request_attrs) do
          {
            'name'       => 'maria',
            'space_guid' => space.guid,
            'buildpack'  => '',
            'state'      => 'STOPPED',
            'health_check_type' => 'port',
          }
        end

        it 'creates the app' do
          process = app_create.create(request_attrs)
          expect(process.app.lifecycle_data.buildpacks).to eq([])
        end
      end
    end
  end
end
