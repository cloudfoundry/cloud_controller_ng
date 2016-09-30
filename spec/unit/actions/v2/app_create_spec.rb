require 'spec_helper'
require 'actions/v2/app_create'

module VCAP::CloudController
  RSpec.describe V2::AppCreate do
    let(:space) { Space.make }
    let(:access_validator) { double('access_validator', validate_access: true) }
    subject(:app_create) { described_class.new(access_validator: access_validator) }

    describe 'create' do
      it 'creates the app' do
        stack = Stack.make(name: 'stacks-on-stacks')

        request_attrs = {
          'name'              => 'maria',
          'space_guid'        => space.guid,
          'environment_json'  => { 'KEY' => 'val' },
          'buildpack'         => 'http://example.com/buildpack',
          'state'             => 'STOPPED',
          'health_check_type' => 'port',
          'stack_guid'        => stack.guid
        }

        v2_app = app_create.create(request_attrs)

        expect(v2_app.name).to eq('maria')
        expect(v2_app.space).to eq(space)
        expect(v2_app.environment_json).to eq({ 'KEY' => 'val' })
        expect(v2_app.stack).to eq(stack)
        expect(v2_app.buildpack.url).to eq('http://example.com/buildpack')

        v3_app = v2_app.app
        expect(v3_app.name).to eq('maria')
        expect(v3_app.space).to eq(space)
        expect(v3_app.environment_variables).to eq({ 'KEY' => 'val' })
        expect(v3_app.lifecycle_type).to eq(BuildpackLifecycleDataModel::LIFECYCLE_TYPE)
        expect(v3_app.lifecycle_data.stack).to eq('stacks-on-stacks')
        expect(v3_app.lifecycle_data.buildpack).to eq('http://example.com/buildpack')
        expect(v3_app.desired_state).to eq(v2_app.state)

        expect(v3_app.guid).to eq(v2_app.guid)
      end

      context 'when custom buildpacks are disabled' do
        before do
          TestConfig.override({ disable_custom_buildpacks: true })
        end

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
          expect { app_create.create(request_attrs) }.to raise_error(/custom buildpacks are disabled/)
        end

        it 'does NOT allow a public http url' do
          request_attrs['buildpack'] = 'http://example.com/foo'
          expect { app_create.create(request_attrs) }.to raise_error(/custom buildpacks are disabled/)
        end

        it 'does allow a buildpack name' do
          admin_buildpack = Buildpack.make
          request_attrs['buildpack'] = admin_buildpack.name
          expect { app_create.create(request_attrs) }.not_to raise_error
        end

        it 'does not allow a private git url' do
          request_attrs['buildpack'] = 'git@example.com:foo.git'
          expect { app_create.create(request_attrs) }.to raise_error(/custom buildpacks are disabled/)
        end

        it 'does not allow a private git url with ssh schema' do
          request_attrs['buildpack'] = 'ssh://git@example.com:foo.git'
          expect { app_create.create(request_attrs) }.to raise_error(/custom buildpacks are disabled/)
        end
      end

      it 'creates docker apps correctly' do
        request_attrs = {
          'name'              => 'maria',
          'space_guid'        => space.guid,
          'state'             => 'STOPPED',
          'health_check_type' => 'port',
          'docker_image'      => 'some-image:latest',
        }

        v2_app = app_create.create(request_attrs)

        expect(v2_app.docker_image).to eq('some-image:latest')
        expect(v2_app.package_hash).to eq('some-image:latest')

        package = v2_app.latest_package
        expect(package.image).to eq('some-image:latest')
      end

      context 'when starting an app without a package' do
        it 'raises an error' do
          request_attrs = {
            'name'              => 'maria',
            'space_guid'        => space.guid,
            'state'             => 'STARTED',
            'health_check_type' => 'port',
          }

          expect { app_create.create(request_attrs) }.to raise_error(/bits have not been uploaded/)
        end
      end
    end
  end
end
