require 'spec_helper'
require 'actions/droplet_create'

module VCAP::CloudController
  RSpec.describe DropletCreate do
    subject(:droplet_create) { DropletCreate.new }
    let(:app) { AppModel.make }
    let(:package) { PackageModel.make app: app }
    let(:build) do
      BuildModel.make(
        app: app,
        package: package,
        created_by_user_guid: 'schneider',
        created_by_user_email: 'bob@loblaw.com',
        created_by_user_name: 'bobert'
      )
    end

    describe '#create_docker_droplet' do
      before do
        package.update(docker_username: 'docker-username', docker_password: 'example-docker-password')
      end

      it 'creates a droplet for build' do
        expect {
          droplet_create.create_docker_droplet(build)
        }.to change { [DropletModel.count, Event.count] }.by([1, 1])

        droplet = DropletModel.last

        expect(droplet.state).to eq(DropletModel::STAGING_STATE)
        expect(droplet.app).to eq(app)
        expect(droplet.package_guid).to eq(package.guid)
        expect(droplet.build).to eq(build)

        expect(droplet.docker_receipt_username).to eq('docker-username')
        expect(droplet.docker_receipt_password).to eq('example-docker-password')

        expect(droplet.buildpack_lifecycle_data).to be_nil

        event = Event.last
        expect(event.type).to eq('audit.app.droplet.create')
        expect(event.actor).to eq('schneider')
        expect(event.actor_type).to eq('user')
        expect(event.actor_name).to eq('bob@loblaw.com')
        expect(event.actor_username).to eq('bobert')
        expect(event.actee).to eq(app.guid)
        expect(event.actee_type).to eq('app')
        expect(event.actee_name).to eq(app.name)
        expect(event.timestamp).to be
        expect(event.space_guid).to eq(app.space_guid)
        expect(event.organization_guid).to eq(app.space.organization.guid)
        expect(event.metadata).to eq({
          'droplet_guid' => droplet.guid,
          'package_guid' => package.guid,
        })
      end

      context 'when the build does not contain created_by fields' do
        let(:build) do
          BuildModel.make(
            app: app,
            package: package,
          )
        end

        it 'sets the actor to UNKNOWN' do
          expect {
            droplet_create.create_docker_droplet(build)
          }.to change { [DropletModel.count, Event.count] }.by([1, 1])

          droplet = DropletModel.last
          expect(droplet.build).to eq(build)

          event = Event.last
          expect(event.type).to eq('audit.app.droplet.create')
          expect(event.actor_type).to eq('user')
          expect(event.actor).to eq('UNKNOWN')
          expect(event.actor_name).to eq('')
          expect(event.actor_username).to eq('')
          expect(event.metadata).to eq({
            'droplet_guid' => droplet.guid,
            'package_guid' => package.guid,
          })
        end
      end
    end

    describe '#create_buildpack_droplet' do
      let!(:buildpack_lifecycle_data) { BuildpackLifecycleDataModel.make(build: build) }

      it 'sets it on the droplet' do
        expect {
          droplet_create.create_buildpack_droplet(build)
        }.to change { [DropletModel.count, Event.count] }.by([1, 1])

        droplet = DropletModel.last

        expect(droplet.state).to eq(DropletModel::STAGING_STATE)
        expect(droplet.app).to eq(app)
        expect(droplet.package).to eq(package)
        expect(droplet.build).to eq(build)

        buildpack_lifecycle_data.reload
        expect(buildpack_lifecycle_data.droplet).to eq(droplet)

        event = Event.last
        expect(event.type).to eq('audit.app.droplet.create')
        expect(event.actor).to eq('schneider')
        expect(event.actor_type).to eq('user')
        expect(event.actor_name).to eq('bob@loblaw.com')
        expect(event.actor_username).to eq('bobert')
        expect(event.actee).to eq(app.guid)
        expect(event.actee_type).to eq('app')
        expect(event.actee_name).to eq(app.name)
        expect(event.timestamp).to be
        expect(event.space_guid).to eq(app.space_guid)
        expect(event.organization_guid).to eq(app.space.organization.guid)
        expect(event.metadata).to eq({
          'droplet_guid' => droplet.guid,
          'package_guid' => package.guid,
        })
      end

      context 'when the build does not contain created_by fields' do
        let(:build) do
          BuildModel.make(
            app: app,
            package: package,
          )
        end

        it 'sets the actor to UNKNOWN' do
          expect {
            droplet_create.create_buildpack_droplet(build)
          }.to change { [DropletModel.count, Event.count] }.by([1, 1])

          droplet = DropletModel.last
          expect(droplet.build).to eq(build)

          event = Event.last
          expect(event.type).to eq('audit.app.droplet.create')
          expect(event.actor_type).to eq('user')
          expect(event.actor).to eq('UNKNOWN')
          expect(event.actor_name).to eq('')
          expect(event.actor_username).to eq('')
          expect(event.metadata).to eq({
            'droplet_guid' => droplet.guid,
            'package_guid' => package.guid,
          })
        end
      end
    end
  end
end
