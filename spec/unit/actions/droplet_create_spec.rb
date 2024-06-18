require 'spec_helper'
require 'actions/droplet_create'

module VCAP::CloudController
  RSpec.describe DropletCreate do
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'amelia@cats.com', user_guid: 'gooid') }
    subject(:droplet_create) { DropletCreate.new }
    let!(:app) { AppModel.make }
    let!(:buildpack_data) { BuildpackLifecycleDataModel.make(app:) }

    let(:docker_app) { AppModel.make(:docker) }
    let(:package) { PackageModel.make app: }
    let(:build) do
      BuildModel.make(
        app: app,
        package: package,
        created_by_user_guid: 'schneider',
        created_by_user_email: 'bob@loblaw.com',
        created_by_user_name: 'bobert'
      )
    end

    describe '#create' do
      context 'when no process_types are specified' do
        let(:message) do
          DropletCreateMessage.new({
                                     relationships: { app: { data: { guid: app.guid } } }
                                   })
        end

        it 'creates a droplet for app including the default process_types' do
          expect do
            droplet_create.create(app, message, user_audit_info)
          end.to change(DropletModel, :count).by(1)

          droplet = DropletModel.last

          expect(droplet.state).to eq(DropletModel::AWAITING_UPLOAD_STATE)
          expect(droplet.app).to eq(app)
          expect(droplet.process_types).to eq({ 'web' => '' })
          expect(droplet.package_guid).to be_nil
          expect(droplet.build).to be_nil
          expect(droplet.buildpack_lifecycle_data.buildpacks).to be_empty
          expect(droplet.buildpack_lifecycle_data.stack).to be_nil
        end

        it 'creates an audit event' do
          expect(Repositories::DropletEventRepository).
            to receive(:record_create).with(instance_of(DropletModel),
                                            user_audit_info,
                                            app.name,
                                            app.space.guid,
                                            app.organization.guid)

          subject.create(app, message, user_audit_info)
        end
      end

      context 'when process_types are specified' do
        let(:message) do
          DropletCreateMessage.new({
                                     relationships: { app: { data: { guid: app.guid } } },
                                     process_types: { web: 'ptype' }
                                   })
        end

        it 'creates a droplet for app with given process_types' do
          expect do
            droplet_create.create(app, message, user_audit_info)
          end.to change(DropletModel, :count).by(1)

          droplet = DropletModel.last

          expect(droplet.state).to eq(DropletModel::AWAITING_UPLOAD_STATE)
          expect(droplet.app).to eq(app)
          expect(droplet.process_types).to eq({ 'web' => 'ptype' })
          expect(droplet.package_guid).to be_nil
          expect(droplet.build).to be_nil
          expect(droplet.buildpack_lifecycle_data.buildpacks).to be_empty
          expect(droplet.buildpack_lifecycle_data.stack).to be_nil
        end

        it 'fails when app has docker lifecycle' do
          expect do
            droplet_create.create(docker_app, message, user_audit_info)
          end.to raise_error(DropletCreate::Error, 'Droplet creation is not available for apps with docker lifecycles.')
        end
      end
    end

    describe '#create_docker_droplet' do
      before do
        package.update(docker_username: 'docker-username', docker_password: 'example-docker-password')
      end

      it 'creates a droplet for build' do
        expect do
          droplet_create.create_docker_droplet(build)
        end.to change { [DropletModel.count, Event.count] }.by([1, 1])

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
                                       'package_guid' => package.guid
                                     })
      end

      context 'when the build does not contain created_by fields' do
        let(:build) do
          BuildModel.make(
            app:,
            package:
          )
        end

        it 'sets the actor to UNKNOWN' do
          expect do
            droplet_create.create_docker_droplet(build)
          end.to change { [DropletModel.count, Event.count] }.by([1, 1])

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
                                         'package_guid' => package.guid
                                       })
        end
      end
    end

    describe '#create_buildpack_droplet' do
      context 'buildpack lifecycle' do
        let!(:buildpack_lifecycle_data) { BuildpackLifecycleDataModel.make(build:) }

        it 'sets it on the droplet' do
          expect do
            droplet_create.create_buildpack_droplet(build)
          end.to change { [DropletModel.count, Event.count] }.by([1, 1])

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
                                         'package_guid' => package.guid
                                       })
        end

        context 'when the build does not contain created_by fields' do
          let(:build) do
            BuildModel.make(
              app:,
              package:
            )
          end

          it 'sets the actor to UNKNOWN' do
            expect do
              droplet_create.create_buildpack_droplet(build)
            end.to change { [DropletModel.count, Event.count] }.by([1, 1])

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
                                           'package_guid' => package.guid
                                         })
          end
        end
      end

      context 'cnb lifecycle' do
        let!(:cnb_lifecycle_data) { CNBLifecycleDataModel.make(build:) }

        it 'sets it on the droplet' do
          expect do
            droplet_create.create_buildpack_droplet(build)
          end.to change { [DropletModel.count, Event.count] }.by([1, 1])

          droplet = DropletModel.last

          expect(droplet.state).to eq(DropletModel::STAGING_STATE)
          expect(droplet.app).to eq(app)
          expect(droplet.package).to eq(package)
          expect(droplet.build).to eq(build)

          cnb_lifecycle_data.reload
          expect(cnb_lifecycle_data.droplet).to eq(droplet)

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
                                         'package_guid' => package.guid
                                       })
        end

        context 'when the build does not contain created_by fields' do
          let(:build) do
            BuildModel.make(
              app:,
              package:
            )
          end

          it 'sets the actor to UNKNOWN' do
            expect do
              droplet_create.create_buildpack_droplet(build)
            end.to change { [DropletModel.count, Event.count] }.by([1, 1])

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
                                           'package_guid' => package.guid
                                         })
          end
        end
      end
    end
  end
end
