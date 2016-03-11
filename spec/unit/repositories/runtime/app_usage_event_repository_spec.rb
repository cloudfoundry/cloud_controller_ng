require 'spec_helper'
require 'repositories/runtime/app_usage_event_repository'

module VCAP::CloudController
  module Repositories::Runtime
    describe AppUsageEventRepository do
      subject(:repository) do
        AppUsageEventRepository.new
      end

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

      describe '#create_from_app' do
        let(:app) { AppFactory.make }

        it 'will create an event which matches the app' do
          event = repository.create_from_app(app)
          expect(event).to match_app(app)
        end

        context 'when a custom state is provided' do
          let(:custom_state) { 'CUSTOM' }

          it 'will populate the event with the custom state' do
            event = repository.create_from_app(app, custom_state)
            expect(event.state).to eq(custom_state)

            event.state = app.state
            expect(event).to match_app(app)
          end
        end

        context 'when the app is created' do
          before do
            app.package_state = package_state
          end

          context 'when the package is pending' do
            let(:package_state) { 'PENDING' }

            it 'will create an event with pending package state' do
              event = repository.create_from_app(app)
              expect(event).to match_app(app)
            end
          end

          context 'when the package is staged' do
            let(:package_state) { 'STAGED' }

            it 'will create an event with staged package state' do
              event = repository.create_from_app(app)
              expect(event).to match_app(app)
            end
          end

          context 'when the package is failed' do
            let(:package_state) { 'FAILED' }

            it 'will create an event with failed package state' do
              event = repository.create_from_app(app)
              expect(event).to match_app(app)
            end
          end
        end

        context 'when an admin buildpack is associated with the app' do
          let(:buildpack) { Buildpack.make }
          before do
            app.admin_buildpack         = buildpack
            app.detected_buildpack_guid = buildpack.guid
            app.detected_buildpack_name = buildpack.name
          end

          it 'will create an event that contains the detected buildpack guid and name' do
            event = repository.create_from_app(app)
            expect(event).to match_app(app)
          end
        end

        context 'when a custom buildpack is associated with the app' do
          let(:buildpack_url) { 'https://git.example.com/repo.git' }

          before do
            app.buildpack = buildpack_url
          end

          it 'will create an event with the buildpack url as the name' do
            event = repository.create_from_app(app)
            expect(event.buildpack_name).to eq(buildpack_url)
          end

          it 'will create an event without a buildpack guid' do
            event = repository.create_from_app(app)
            expect(event.buildpack_guid).to be_nil
          end
        end

        context "when the DEA doesn't provide optional buildpack information" do
          before do
            app.buildpack = nil
          end

          it 'will create an event that does not contain buildpack name or guid' do
            event = repository.create_from_app(app)
            expect(event.buildpack_guid).to be_nil
            expect(event.buildpack_name).to be_nil
          end
        end

        context 'fails to create the event' do
          before do
            app.state = nil
          end

          it 'will raise an error' do
            expect {
              repository.create_from_app(app)
            }.to raise_error(Sequel::NotNullConstraintViolation)
          end
        end

        context 'when the app is a v3 process' do
          let(:app_name) { 'v3_app_name' }
          let(:v3_app) { AppModel.make(name: 'v3_app_name') }
          let(:app_guid) { v3_app.guid }

          before do
            v3_app.add_process_by_guid(app.guid)
            app.reload
          end

          it 'records information about the parent app' do
            event = repository.create_from_app(app)

            expect(event.parent_app_name).to eq(app_name)
            expect(event.parent_app_guid).to eq(app_guid)
            expect(event.process_type).to eq(app.type)
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
            expect(event.instance_count).to eq(1)
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
            expect(event.package_state).to eq('STAGED')
            expect(event.parent_app_guid).to eq(task.app.guid)
            expect(event.parent_app_guid).to be_present
            expect(event.parent_app_name).to eq(task.app.name)
            expect(event.parent_app_name).to be_present
            expect(event.process_type).to be_nil
            expect(event.task_guid).to eq(task.guid)
            expect(event.task_name).to eq(task.name)
          end
        end
      end

      describe '#create_from_droplet' do
        let(:package) { PackageModel.make }
        let!(:droplet) { DropletModel.make(memory_limit: 222, package_guid: package.guid) }
        let(:state) { 'TEST_STATE' }

        it 'creates an AppUsageEvent' do
          expect {
            repository.create_from_droplet(droplet, state)
          }.to change { AppUsageEvent.count }.by(1)
        end

        describe 'the created event' do
          it 'sets the state to what is passed in' do
            event = repository.create_from_droplet(droplet, state)
            expect(event.state).to eq('TEST_STATE')
          end

          it 'sets the attributes based on the task' do
            event = repository.create_from_droplet(droplet, state)

            expect(event.state).to eq('TEST_STATE')
            expect(event.instance_count).to eq(1)
            expect(event.memory_in_mb_per_instance).to eq(222)
            expect(event.org_guid).to eq(droplet.space.organization.guid)
            expect(event.space_guid).to eq(droplet.space.guid)
            expect(event.space_name).to eq(droplet.space.name)
            expect(event.parent_app_guid).to eq(droplet.app.guid)
            expect(event.parent_app_name).to eq(droplet.app.name)
            expect(event.package_guid).to eq(droplet.package.guid)
            expect(event.app_guid).to eq('')
            expect(event.app_name).to eq('')
            expect(event.process_type).to be_nil
            expect(event.buildpack_guid).to be_nil
            expect(event.buildpack_name).to be_nil
            expect(event.package_state).to be_nil
            expect(event.task_guid).to be_nil
            expect(event.task_name).to be_nil
          end
        end
      end

      describe '#purge_and_reseed_started_apps!' do
        let(:app) { AppFactory.make }

        before do
          # Truncate in mysql causes an implicit commit.
          # This stub will cause the same behavior, but not commit.
          allow(AppUsageEvent.dataset).to receive(:truncate) do
            AppUsageEvent.dataset.delete
          end
          allow(AppObserver).to receive(:updated)
        end

        it 'will purge all existing events' do
          3.times { repository.create_from_app(app) }

          expect {
            repository.purge_and_reseed_started_apps!
          }.to change { AppUsageEvent.count }.to(0)
        end

        context 'when there are started apps' do
          before do
            app.state = 'STARTED'
            app.save
          end

          it 'creates new events for the started apps' do
            app.state = 'STOPPED'
            repository.create_from_app(app)
            app.state = 'STARTED'
            repository.create_from_app(app)

            started_app_count = App.where(state: 'STARTED').count

            expect(AppUsageEvent.count > 1).to be true
            expect {
              repository.purge_and_reseed_started_apps!
            }.to change { AppUsageEvent.count }.to(started_app_count)

            expect(AppUsageEvent.last).to match_app(app)
          end

          context 'with associated buildpack information' do
            let(:buildpack) { Buildpack.make }

            before do
              app.buildpack               = buildpack.name
              app.detected_buildpack      = 'Detect script output'
              app.detected_buildpack_guid = buildpack.guid
              app.detected_buildpack_name = buildpack.name
              app.save
            end

            it 'should preserve the buildpack info in the new event' do
              repository.purge_and_reseed_started_apps!
              event = AppUsageEvent.last

              expect(event).to match_app(app)
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
            event            = repository.create_from_app(App.make)
            event.created_at = old
            event.save
          end
        end

        it 'will delete events created before the specified cutoff time' do
          app = App.make
          repository.create_from_app(app)

          expect {
            repository.delete_events_older_than(cutoff_age_in_days)
          }.to change {
            AppUsageEvent.count
          }.to(1)

          expect(AppUsageEvent.last).to match_app(app)
        end
      end
    end
  end
end
