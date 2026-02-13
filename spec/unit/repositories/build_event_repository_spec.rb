require 'spec_helper'
require 'repositories/build_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe BuildEventRepository do
      let(:app) { AppModel.make(name: 'popsicle') }
      let(:user) { User.make }
      let(:package) { PackageModel.make(app_guid: app.guid) }
      let(:email) { 'user-email' }
      let(:user_name) { 'user-name' }
      let(:build) do
        BuildModel.make(
          app_guid: app.guid,
          package: package,
          created_by_user_guid: user.guid,
          created_by_user_name: user_name,
          created_by_user_email: email
        )
      end
      let(:user_audit_info) { UserAuditInfo.new(user_email: email, user_name: user_name, user_guid: user.guid) }

      describe '#record_build_create' do
        it 'creates a new audit.app.build.create event' do
          event = BuildEventRepository.record_build_create(build, user_audit_info, app.name, package.space.guid, package.space.organization.guid)
          event.reload

          expect(event.type).to eq('audit.app.build.create')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(build.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)

          metadata = event.metadata
          expect(metadata['build_guid']).to eq(build.guid)
          expect(metadata['package_guid']).to eq(package.guid)
        end
      end

      describe '#record_build_staged' do
        let(:droplet) { DropletModel.make(app_guid: app.guid, package: package, build: build) }

        it 'creates a new audit.app.build.staged event' do
          event = BuildEventRepository.record_build_staged(build, droplet)
          event.reload

          expect(event.type).to eq('audit.app.build.staged')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)

          metadata = event.metadata
          expect(metadata['build_guid']).to eq(build.guid)
          expect(metadata['package_guid']).to eq(package.guid)
          expect(metadata['droplet_guid']).to eq(droplet.guid)
          expect(metadata['buildpacks']).to eq([])
        end

        context 'cnb lifecycle' do
          let(:build) do
            BuildModel.make(:cnb,
                            app_guid: app.guid,
                            package: package,
                            created_by_user_guid: user.guid,
                            created_by_user_name: user_name,
                            created_by_user_email: email)
          end
          let(:droplet) { DropletModel.make(:cnb, app_guid: app.guid, package: package, build: build) }

          it 'creates a new audit.app.build.staged event' do
            event = BuildEventRepository.record_build_staged(build, droplet)
            event.reload

            expect(event.type).to eq('audit.app.build.staged')
            expect(event.metadata['buildpacks']).to eq([])
          end
        end

        context 'docker lifecycle' do
          let(:build) do
            BuildModel.make(:docker,
                            app_guid: app.guid,
                            package: package,
                            created_by_user_guid: user.guid,
                            created_by_user_name: user_name,
                            created_by_user_email: email)
          end
          let(:droplet) { DropletModel.make(:docker, app_guid: app.guid, package: package, build: build) }

          it 'creates a new audit.app.build.staged event' do
            event = BuildEventRepository.record_build_staged(build, droplet)
            event.reload

            expect(event.type).to eq('audit.app.build.staged')
            expect(event.metadata['buildpacks']).to be_nil
          end
        end

        context 'when the droplet has buildpack lifecycle data' do
          let!(:admin_buildpack) { Buildpack.make(name: 'ruby_buildpack') }
          let(:lifecycle_data) { BuildpackLifecycleDataModel.make(droplet:, build:) }
          let!(:lifecycle_buildpack1) do
            BuildpackLifecycleBuildpackModel.make(
              buildpack_lifecycle_data: lifecycle_data,
              admin_buildpack_name: 'ruby_buildpack',
              buildpack_name: 'ruby',
              version: '1.8.0'
            )
          end
          let!(:lifecycle_buildpack2) do
            BuildpackLifecycleBuildpackModel.make(
              buildpack_lifecycle_data: lifecycle_data,
              admin_buildpack_name: nil,
              buildpack_url: 'https://user:password@github.com/custom/buildpack',
              buildpack_name: 'custom-bp',
              version: '2.0.0'
            )
          end

          before do
            droplet.buildpack_lifecycle_data = lifecycle_data
            droplet.save
          end

          it 'includes buildpack information in metadata' do
            event = BuildEventRepository.record_build_staged(build, droplet)
            event.reload

            buildpacks = event.metadata['buildpacks']
            expect(buildpacks).to have(2).items

            expect(buildpacks[0]['name']).to eq('ruby_buildpack')
            expect(buildpacks[0]['buildpack_name']).to eq('ruby')
            expect(buildpacks[0]['version']).to eq('1.8.0')

            expect(buildpacks[1]['name']).to eq('https://***:***@github.com/custom/buildpack')
            expect(buildpacks[1]['buildpack_name']).to eq('custom-bp')
            expect(buildpacks[1]['version']).to eq('2.0.0')
          end
        end

        context 'when the droplet has no lifecycle data' do
          it 'sets buildpacks to empty array in metadata' do
            event = BuildEventRepository.record_build_staged(build, droplet)
            event.reload

            expect(event.metadata['buildpacks']).to eq([])
          end
        end
      end

      describe '#record_build_failed' do
        let(:error_id) { 'StagingError' }
        let(:error_message) { 'Something went wrong during staging' }

        context 'buildpack lifecycle' do
          it 'creates a new audit.app.build.failed event' do
            event = BuildEventRepository.record_build_failed(build, error_id, error_message)
            event.reload

            expect(event.type).to eq('audit.app.build.failed')
            expect(event.actor).to eq(user.guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(email)
            expect(event.actor_username).to eq(user_name)
            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('app')
            expect(event.actee_name).to eq('popsicle')
            expect(event.space_guid).to eq(app.space.guid)
            expect(event.organization_guid).to eq(app.space.organization.guid)

            metadata = event.metadata
            expect(metadata['build_guid']).to eq(build.guid)
            expect(metadata['package_guid']).to eq(package.guid)
            expect(metadata['error_id']).to eq(error_id)
            expect(metadata['error_message']).to eq(error_message)
          end
        end

        context 'cnb lifecycle' do
          let(:build) do
            BuildModel.make(:cnb,
                            app_guid: app.guid,
                            package: package,
                            created_by_user_guid: user.guid,
                            created_by_user_name: user_name,
                            created_by_user_email: email)
          end

          it 'creates a new audit.app.build.failed event' do
            event = BuildEventRepository.record_build_failed(build, error_id, error_message)
            event.reload

            expect(event.type).to eq('audit.app.build.failed')
          end
        end

        context 'docker lifecycle' do
          let(:build) do
            BuildModel.make(:docker,
                            app_guid: app.guid,
                            package: package,
                            created_by_user_guid: user.guid,
                            created_by_user_name: user_name,
                            created_by_user_email: email)
          end

          it 'creates a new audit.app.build.failed event' do
            event = BuildEventRepository.record_build_failed(build, error_id, error_message)
            event.reload

            expect(event.type).to eq('audit.app.build.failed')
          end
        end
      end
    end
  end
end
