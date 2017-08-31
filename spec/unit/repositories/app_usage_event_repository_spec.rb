require 'spec_helper'
require 'repositories/app_usage_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe AppUsageEventRepository do
      subject(:repository) { AppUsageEventRepository.new }

      describe '#find' do
        context 'when the event exists' do
          let(:event) { AppUsageEvent.make }

          it 'should return the event' do
            expect(repository.find(event.guid)).to eq(event)
          end
        end

        context 'when the event does not exist' do
          it 'should return nil' do
            expect(repository.find('does-not-exist')).to be_nil
          end
        end
      end

      describe '#create_from_process' do
        let(:parent_app) { AppModel.make(name: 'parent-app') }
        let(:process) { ProcessModelFactory.make(app: parent_app, type: 'other') }

        it 'will create an event which matches the app' do
          event = repository.create_from_process(process)
          expect(event).to match_app(process)
          expect(event.parent_app_name).to eq('parent-app')
          expect(event.parent_app_guid).to eq(parent_app.guid)
          expect(event.process_type).to eq('other')
        end

        it 'will create an event with default previous attributes' do
          event = repository.create_from_process(process)

          default_instances = ProcessModel.db_schema[:instances][:default].to_i
          default_memory    = VCAP::CloudController::Config.config.get(:default_app_memory)

          expect(event.previous_state).to eq('STOPPED')
          expect(event.previous_instance_count).to eq(default_instances)
          expect(event.previous_memory_in_mb_per_instance).to eq(default_memory)
        end

        context 'when a custom state is provided' do
          let(:custom_state) { 'CUSTOM' }

          it 'will populate the event with the custom state' do
            event = repository.create_from_process(process, custom_state)
            expect(event.state).to eq(custom_state)

            event.state = process.state
            expect(event).to match_app(process)
          end
        end

        context 'when the app is created' do
          context 'when the package is pending' do
            before do
              process.current_droplet.destroy
              process.reload
            end

            it 'will create an event with pending package state' do
              event = repository.create_from_process(process)
              expect(event).to match_app(process)
            end
          end

          context 'when the package is staged' do
            it 'will create an event with staged package state' do
              event = repository.create_from_process(process)
              expect(event).to match_app(process)
            end
          end

          context 'when the package is failed' do
            before do
              process.current_droplet.update(state: DropletModel::FAILED_STATE)
              process.reload
            end
            it 'will create an event with failed package state' do
              event = repository.create_from_process(process)
              expect(event).to match_app(process)
            end
          end
        end

        context 'when an admin buildpack is associated with the app' do
          before do
            process.current_droplet.update(
              buildpack_receipt_buildpack_guid: 'buildpack-guid',
              buildpack_receipt_buildpack:      'buildpack-name'
            )
          end

          it 'will create an event that contains the detected buildpack guid and name' do
            event = repository.create_from_process(process)
            expect(event).to match_app(process)
            expect(event.buildpack_guid).to eq('buildpack-guid')
            expect(event.buildpack_name).to eq('buildpack-name')
          end
        end

        context 'when a custom buildpack is associated with the app' do
          let(:buildpack_url) { 'https://git.example.com/repo.git' }

          before do
            process.app.lifecycle_data.update(buildpacks: [buildpack_url])
          end

          it 'will create an event with the buildpack url as the name' do
            event = repository.create_from_process(process)
            expect(event.buildpack_name).to eq('https://git.example.com/repo.git')
          end

          context 'where there are user credentials in the buildpack url' do
            let(:buildpack_url) { 'https://super:secret@git.example.com/repo.git' }

            it 'redacts them' do
              event = repository.create_from_process(process)
              expect(event.buildpack_name).to eq('https://***:***@git.example.com/repo.git')
            end
          end

          it 'will create an event without a buildpack guid' do
            event = repository.create_from_process(process)
            expect(event.buildpack_guid).to be_nil
          end
        end

        context "when the DEA doesn't provide optional buildpack information" do
          before do
            process.app.lifecycle_data.update(buildpacks: nil)
          end

          it 'will create an event that does not contain buildpack name or guid' do
            event = repository.create_from_process(process)
            expect(event.buildpack_guid).to be_nil
            expect(event.buildpack_name).to be_nil
          end
        end

        context 'fails to create the event' do
          before do
            process.state = nil
          end

          it 'will raise an error' do
            expect {
              repository.create_from_process(process)
            }.to raise_error(Sequel::NotNullConstraintViolation)
          end
        end

        context 'when the app already existed' do
          let(:old_state) { 'STARTED' }
          let(:old_instances) { 4 }
          let(:old_memory) { 256 }
          let(:process) { ProcessModelFactory.make(state: old_state, instances: old_instances, memory: old_memory) }

          it 'always sets previous_package_state to UNKNOWN' do
            event = repository.create_from_process(process)
            expect(event.previous_package_state).to eq('UNKNOWN')
          end

          context 'when the same attribute values are set' do
            before do
              process.state     = old_state
              process.instances = old_instances
              process.memory    = old_memory
            end

            it 'creates event with previous attributes' do
              event = repository.create_from_process(process)

              expect(event.previous_state).to eq(old_state)
              expect(event.previous_instance_count).to eq(old_instances)
              expect(event.previous_memory_in_mb_per_instance).to eq(old_memory)
            end
          end

          context 'when app attributes change' do
            let(:new_state) { 'STOPPED' }
            let(:new_instances) { 2 }
            let(:new_memory) { 1024 }

            before do
              process.state     = new_state
              process.instances = new_instances
              process.memory    = new_memory
            end

            it 'stores new values' do
              event = repository.create_from_process(process)

              expect(event.state).to eq(new_state)
              expect(event.instance_count).to eq(new_instances)
              expect(event.memory_in_mb_per_instance).to eq(new_memory)
            end

            it 'stores previous values' do
              event = repository.create_from_process(process)

              expect(event.previous_state).to eq(old_state)
              expect(event.previous_instance_count).to eq(old_instances)
              expect(event.previous_memory_in_mb_per_instance).to eq(old_memory)
            end
          end
        end
      end

      describe '#create_from_task' do
        let!(:task) { TaskModel.make(memory_in_mb: 222) }
        let(:state) { 'TEST_STATE' }

        it 'creates an AppUsageEvent' do
          expect {
            repository.create_from_task(task, state)
          }.to change { AppUsageEvent.count }.by(1)
        end

        describe 'the created event' do
          it 'sets the state to what is passed in' do
            event = repository.create_from_task(task, state)
            expect(event.state).to eq('TEST_STATE')
          end

          it 'sets the attributes based on the task' do
            event = repository.create_from_task(task, state)

            expect(event.memory_in_mb_per_instance).to eq(222)
            expect(event.previous_memory_in_mb_per_instance).to eq(222)
            expect(event.instance_count).to eq(1)
            expect(event.previous_instance_count).to eq(1)
            expect(event.app_guid).to eq('')
            expect(event.app_name).to eq('')
            expect(event.space_guid).to eq(task.space.guid)
            expect(event.space_guid).to be_present
            expect(event.space_name).to eq(task.space.name)
            expect(event.space_name).to be_present
            expect(event.org_guid).to eq(task.space.organization.guid)
            expect(event.org_guid).to be_present
            expect(event.buildpack_guid).to be_nil
            expect(event.buildpack_name).to be_nil
            expect(event.previous_state).to eq('RUNNING')
            expect(event.package_state).to eq('STAGED')
            expect(event.previous_package_state).to eq('STAGED')
            expect(event.parent_app_guid).to eq(task.app.guid)
            expect(event.parent_app_guid).to be_present
            expect(event.parent_app_name).to eq(task.app.name)
            expect(event.parent_app_name).to be_present
            expect(event.process_type).to be_nil
            expect(event.task_guid).to eq(task.guid)
            expect(event.task_name).to eq(task.name)
          end
        end

        context 'when the task exists' do
          let(:old_state) { TaskModel::RUNNING_STATE }
          let(:old_memory) { 256 }
          let(:existing_task) { TaskModel.make(state: old_state, memory_in_mb: old_memory) }

          context 'when the same attribute values are set' do
            before do
              existing_task.memory_in_mb = old_memory
            end

            it 'creates event with previous attributes' do
              event = repository.create_from_task(existing_task, state)

              expect(event.previous_state).to eq(old_state)
              expect(event.previous_package_state).to eq('STAGED')
              expect(event.previous_instance_count).to eq(1)
              expect(event.previous_memory_in_mb_per_instance).to eq(old_memory)
            end
          end

          context 'when task attributes change' do
            let(:new_state) { TaskModel::FAILED_STATE }
            let(:new_memory) { 1024 }

            before do
              existing_task.memory_in_mb = new_memory
            end

            it 'stores new values' do
              event = repository.create_from_task(existing_task, new_state)

              expect(event.state).to eq(new_state)
              expect(event.memory_in_mb_per_instance).to eq(new_memory)
            end

            it 'stores previous values' do
              event = repository.create_from_task(existing_task, state)

              expect(event.previous_state).to eq(old_state)
              expect(event.previous_package_state).to eq('STAGED')
              expect(event.previous_instance_count).to eq(1)
              expect(event.previous_memory_in_mb_per_instance).to eq(old_memory)
            end
          end
        end
      end

      describe '#create_from_build' do
        let(:org) { Organization.make(guid: 'org-1') }
        let(:space) { Space.make(guid: 'space-1', name: 'space-name', organization: org) }
        let(:app_model) { AppModel.make(guid: 'app-1', name: 'frank-app', space: space) }
        let(:package_state) { PackageModel::READY_STATE }
        let(:package) { PackageModel.make(guid: 'package-1', app_guid: app_model.guid, state: package_state) }
        let!(:build) { BuildModel.make(guid: 'build-1', package: package, app_guid: app_model.guid, state: BuildModel::STAGING_STATE) }

        let(:state) { 'TEST_STATE' }

        it 'creates an AppUsageEvent' do
          expect {
            repository.create_from_build(build, state)
          }.to change { AppUsageEvent.count }.by(1)
        end

        describe 'the created event' do
          it 'sets the state to what is passed in' do
            event = repository.create_from_build(build, state)
            expect(event.state).to eq('TEST_STATE')
          end

          it 'sets the attributes based on the build' do
            build.update(
              droplet: DropletModel.make(buildpack_receipt_buildpack: 'le-buildpack'),
              buildpack_lifecycle_data: BuildpackLifecycleDataModel.make
            )
            event = repository.create_from_build(build, state)

            expect(event.state).to eq('TEST_STATE')
            expect(event.previous_state).to eq('STAGING')
            expect(event.instance_count).to eq(1)
            expect(event.previous_instance_count).to eq(1)
            expect(event.memory_in_mb_per_instance).to eq(1024)
            expect(event.previous_memory_in_mb_per_instance).to eq(1024)
            expect(event.org_guid).to eq('org-1')
            expect(event.space_guid).to eq('space-1')
            expect(event.space_name).to eq('space-name')
            expect(event.parent_app_guid).to eq('app-1')
            expect(event.parent_app_name).to eq('frank-app')
            expect(event.package_guid).to eq('package-1')
            expect(event.app_guid).to eq('')
            expect(event.app_name).to eq('')
            expect(event.process_type).to be_nil
            expect(event.buildpack_name).to eq('le-buildpack')
            expect(event.buildpack_guid).to be_nil
            expect(event.package_state).to eq(package_state)
            expect(event.previous_package_state).to eq(package_state)
            expect(event.task_guid).to be_nil
            expect(event.task_name).to be_nil
          end
        end

        context 'buildpack builds' do
          context 'when the build does NOT have an associated droplet but does have lifecycle data' do
            before do
              build.update(
                buildpack_lifecycle_data: BuildpackLifecycleDataModel.make(buildpacks: ['http://git.url.example.com'])
              )
            end

            it 'sets the event buildpack_name to the lifecycle data buildpack' do
              event = repository.create_from_build(build, state)

              expect(event.buildpack_name).to eq('http://git.url.example.com')
              expect(event.buildpack_guid).to be_nil
            end

            context 'when buildpack lifecycle info contains credentials in buildpack url' do
              before do
                build.update(
                  buildpack_lifecycle_data: BuildpackLifecycleDataModel.make(buildpacks: ['http://ping:pong@example.com'])
                )
              end

              it 'redacts credentials from the url' do
                event = repository.create_from_build(build, state)

                expect(event.buildpack_name).to eq('http://***:***@example.com')
                expect(event.buildpack_guid).to be_nil
              end
            end
          end

          context 'when the build has BOTH an associated droplet and lifecycle data' do
            let!(:build) do
              BuildModel.make(
                :buildpack,
                guid:         'build-1',
                package_guid: package.guid,
                app_guid:     app_model.guid,
              )
            end
            let!(:droplet) do
              DropletModel.make(
                :buildpack,
                buildpack_receipt_buildpack:      'a-buildpack',
                buildpack_receipt_buildpack_guid: 'a-buildpack-guid',
                build:                            build
              )
            end

            before do
              Buildpack.make(name: 'ruby_buildpack')
              build.update(
                buildpack_lifecycle_data: BuildpackLifecycleDataModel.make(buildpacks: ['ruby_buildpack'])
              )
            end

            it 'prefers the buildpack receipt info' do
              event = repository.create_from_build(build, state)

              expect(event.buildpack_name).to eq('a-buildpack')
              expect(event.buildpack_guid).to eq('a-buildpack-guid')
            end
          end
        end

        context 'docker builds' do
          let!(:build) do
            BuildModel.make(
              :docker,
              guid:         'build-1',
              package_guid: package.guid,
              app_guid:     app_model.guid,
            )
          end

          it 'does not include buildpack_guid or buildpack_name' do
            event = repository.create_from_build(build, state)

            expect(event.buildpack_name).to be_nil
            expect(event.buildpack_guid).to be_nil
          end
        end

        context 'when the build is updating its state' do
          let(:old_build_state) { BuildModel::STAGED_STATE }
          let(:existing_build) { BuildModel.make(
            guid:     'existing-build',
            state:    old_build_state,
            package:  package,
            app_guid: app_model.guid)
          }

          context 'when the same attribute values are set' do
            before do
              existing_build.state = old_build_state
            end

            it 'creates event with previous attributes' do
              event = repository.create_from_build(existing_build, state)

              expect(event.previous_state).to eq(old_build_state)
              expect(event.previous_package_state).to eq(package_state)
              expect(event.previous_instance_count).to eq(1)
            end
          end

          context 'when package attributes change' do
            let(:new_state) { BuildModel::STAGED_STATE }
            let(:new_package_state) { PackageModel::FAILED_STATE }
            let(:new_memory) { 1024 }

            before do
              existing_build.package.state = new_package_state
            end

            it 'stores new values' do
              event = repository.create_from_build(existing_build, new_state)

              expect(event.state).to eq(new_state)
              expect(event.package_state).to eq(new_package_state)
              expect(event.instance_count).to eq(1)
            end

            it 'stores previous values' do
              event = repository.create_from_build(existing_build, new_state)

              expect(event.previous_state).to eq(old_build_state)
              expect(event.previous_package_state).to eq(package_state)
              expect(event.previous_instance_count).to eq(1)
            end
          end

          context 'when the build has no package' do
            let(:existing_build) { BuildModel.make(guid: 'existing-build', state: old_build_state, app_guid: app_model.guid) }

            context 'when an attribute changes' do
              before do
                existing_build.state = BuildModel::STAGED_STATE
              end

              it 'returns no previous package state' do
                event = repository.create_from_build(existing_build, state)
                expect(event.previous_package_state).to be_nil
              end
            end
          end
        end
      end

      describe '#purge_and_reseed_started_apps!' do
        let(:process) { ProcessModelFactory.make }

        before do
          # Truncate in mysql causes an implicit commit.
          # This stub will cause the same behavior, but not commit.
          allow(AppUsageEvent.dataset).to receive(:truncate) do
            AppUsageEvent.dataset.delete
          end
          allow(AppObserver).to receive(:updated)
        end

        it 'will purge all existing events' do
          3.times { repository.create_from_process(process) }

          expect {
            repository.purge_and_reseed_started_apps!
          }.to change { AppUsageEvent.count }.to(0)
        end

        context 'when there are started apps' do
          before do
            process.state = 'STARTED'
            process.save
            ProcessModelFactory.make(state: 'STOPPED')
          end

          it 'creates new events for the started apps' do
            process.state = 'STOPPED'
            repository.create_from_process(process)
            process.state = 'STARTED'
            repository.create_from_process(process)

            started_app_count = ProcessModel.where(state: 'STARTED').count

            expect(AppUsageEvent.count > 1).to be true
            expect {
              repository.purge_and_reseed_started_apps!
            }.to change { AppUsageEvent.count }.to(started_app_count)

            expect(AppUsageEvent.last).to match_app(process)
          end

          context 'with associated buildpack information' do
            before do
              process.current_droplet.update(
                buildpack_receipt_buildpack:      'detected-name',
                buildpack_receipt_buildpack_guid: 'detected-guid',
              )
              process.reload
            end

            it 'should preserve the buildpack info in the new event' do
              repository.purge_and_reseed_started_apps!
              event = AppUsageEvent.last

              expect(event).to match_app(process)
              expect(event.buildpack_name).to eq('detected-name')
              expect(event.buildpack_guid).to eq('detected-guid')
            end
          end

          describe 'package_state' do
            context 'when the latest_droplet is STAGED' do
              context 'and there is no current_droplet' do
                before do
                  process.app.update(droplet: nil)
                  process.reload
                end

                it 'is PENDING' do
                  repository.purge_and_reseed_started_apps!
                  expect(AppUsageEvent.last).to match_app(process)
                  expect(AppUsageEvent.last.package_state).to eq('PENDING')
                  expect(AppUsageEvent.last.previous_package_state).to eq('UNKNOWN')
                end
              end

              context 'and it is the current_droplet' do
                it 'is STAGED' do
                  repository.purge_and_reseed_started_apps!
                  expect(AppUsageEvent.last).to match_app(process)
                  expect(AppUsageEvent.last.package_state).to eq('STAGED')
                  expect(AppUsageEvent.last.previous_package_state).to eq('UNKNOWN')
                end
              end
            end

            context 'when the latest_droplet is FAILED' do
              before do
                DropletModel.make(app: process.app, package: process.latest_package, state: DropletModel::FAILED_STATE)
                process.reload
              end

              it 'is FAILED' do
                repository.purge_and_reseed_started_apps!
                expect(AppUsageEvent.last).to match_app(process)
                expect(AppUsageEvent.last.package_state).to eq('FAILED')
                expect(AppUsageEvent.last.previous_package_state).to eq('UNKNOWN')
              end
            end

            context 'when the latest_droplet is not STAGED or FAILED' do
              before do
                DropletModel.make(app: process.app, package: process.latest_package, state: DropletModel::STAGING_STATE)
                process.reload
              end

              it 'is PENDING' do
                repository.purge_and_reseed_started_apps!
                expect(AppUsageEvent.last).to match_app(process)
                expect(AppUsageEvent.last.package_state).to eq('PENDING')
                expect(AppUsageEvent.last.previous_package_state).to eq('UNKNOWN')
              end
            end

            context 'when there is no current_droplet' do
              before do
                process.current_droplet.destroy
                process.reload
              end

              context 'and there is a package' do
                it 'is PENDING' do
                  repository.purge_and_reseed_started_apps!
                  expect(AppUsageEvent.last).to match_app(process)
                  expect(AppUsageEvent.last.package_state).to eq('PENDING')
                  expect(AppUsageEvent.last.previous_package_state).to eq('UNKNOWN')
                end
              end

              context 'and the package is FAILED' do
                before do
                  process.latest_package.update(state: PackageModel::FAILED_STATE)
                  process.reload
                end

                it 'is FAILED' do
                  repository.purge_and_reseed_started_apps!
                  expect(AppUsageEvent.last).to match_app(process)
                  expect(AppUsageEvent.last.package_state).to eq('FAILED')
                  expect(AppUsageEvent.last.previous_package_state).to eq('UNKNOWN')
                end
              end
            end

            context 'when a new package has been added to a previously staged app' do
              before do
                PackageModel.make(app: process.app)
                process.reload
              end

              it 'is PENDING' do
                repository.purge_and_reseed_started_apps!
                expect(AppUsageEvent.last).to match_app(process)
                expect(AppUsageEvent.last.package_state).to eq('PENDING')
                expect(AppUsageEvent.last.previous_package_state).to eq('UNKNOWN')
              end
            end
          end
        end
      end

      describe '#delete_events_older_than' do
        let(:cutoff_age_in_days) { 1 }
        before do
          AppUsageEvent.dataset.delete

          old = Time.now.utc - 999.days

          3.times do
            event            = repository.create_from_process(ProcessModel.make)
            event.created_at = old
            event.save
          end
        end

        it 'will delete events created before the specified cutoff time' do
          process = ProcessModel.make
          repository.create_from_process(process)

          expect {
            repository.delete_events_older_than(cutoff_age_in_days)
          }.to change {
            AppUsageEvent.count
          }.to(1)

          expect(AppUsageEvent.last).to match_app(process)
        end
      end
    end
  end
end
