require 'spec_helper'

module VCAP::CloudController
  RSpec.describe TaskModel do
    let(:parent_app) { AppModel.make }

    describe 'after create' do
      it 'does not create a TASK_STARTED event' do
        task = TaskModel.make(app: parent_app, state: TaskModel::PENDING_STATE)

        event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STARTED')
        expect(event).to be_nil
      end
    end

    describe 'after update' do
      let(:task) { TaskModel.make(app: parent_app, state: TaskModel::PENDING_STATE) }

      context 'when the task is moving to the SUCCEEDED_STATE' do
        let(:task) { TaskModel.make(app: parent_app, state: TaskModel::RUNNING_STATE) }
        let!(:start_event) { AppUsageEvent.make(task_guid: task.guid, state: 'TASK_STARTED') }

        it 'creates a TASK_STOPPED event' do
          task.update(state: TaskModel::SUCCEEDED_STATE)

          event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
          expect(event).not_to be_nil
          expect(event.task_guid).to eq(task.guid)
          expect(event.parent_app_guid).to eq(task.app.guid)
        end
      end

      context 'when the task is moving to the FAILED_STATE' do
        context 'when the task is moving from the RUNNING state' do
          let!(:start_event) { AppUsageEvent.make(task_guid: task.guid, state: 'TASK_STARTED') }
          let(:task) { TaskModel.make(app: parent_app, state: TaskModel::RUNNING_STATE) }

          it 'creates a TASK_STOPPED event' do
            task.update(state: TaskModel::FAILED_STATE)

            event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
            expect(event).not_to be_nil
            expect(event.task_guid).to eq(task.guid)
            expect(event.parent_app_guid).to eq(task.app.guid)
          end
        end

        context 'when the task is moving from the PENDING state' do
          let(:task) { TaskModel.make(app: parent_app, state: TaskModel::PENDING_STATE) }

          it 'does not create a TASK_STOPPED event' do
            task.update(state: TaskModel::FAILED_STATE)

            event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
            expect(event).to be_nil
          end
        end

        context 'when the task is moving from the CANCELING state' do
          let(:task) { TaskModel.make(app: parent_app, state: TaskModel::CANCELING_STATE) }

          context 'when the task has a TASK_STARTED event' do
            let!(:start_event) { AppUsageEvent.make(task_guid: task.guid, state: 'TASK_STARTED') }

            it 'creates a TASK_STOPPED event' do
              task.update(state: TaskModel::FAILED_STATE)

              event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
              expect(event).not_to be_nil
              expect(event.task_guid).to eq(task.guid)
              expect(event.parent_app_guid).to eq(task.app.guid)
            end
          end

          context 'when the task does not have a TASK_STARTED event' do
            let!(:start_event) { nil }

            it 'does not create a TASK_STOPPED event' do
              task.update(state: TaskModel::FAILED_STATE)

              event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
              expect(event).to be_nil
            end
          end
        end

        context 'when the task already has a TASK_STOPPED event' do
          let!(:start_event) { AppUsageEvent.make(task_guid: task.guid, state: 'TASK_STARTED') }

          before do
            AppUsageEvent.make(task_guid: task.guid, state: 'TASK_STOPPED')
          end

          it 'does not create additional TASK_STOPPED event' do
            task.update(state: TaskModel::FAILED_STATE)

            events = AppUsageEvent.where(task_guid: task.guid, state: 'TASK_STOPPED')
            expect(events.count).to equal(1)
          end
        end
      end

      context 'when the task is moving to RUNNING_STATE' do
        it 'does not create a TASK_STOPPED event' do
          task.update(state: TaskModel::RUNNING_STATE)

          event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
          expect(event).to be_nil
        end

        it 'creates a TASK_STARTED event' do
          task.update(state: TaskModel::RUNNING_STATE)

          event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STARTED')
          expect(event).not_to be_nil
          expect(event.task_guid).to eq(task.guid)
          expect(event.parent_app_guid).to eq(task.app.guid)
        end
      end

      context 'when the state is not changing' do
        let!(:start_event) { AppUsageEvent.make(task_guid: task.guid, state: 'TASK_STARTED') }
        let(:task) { TaskModel.make(app: parent_app, state: TaskModel::FAILED_STATE) }

        it 'does not create a TASK_STOPPED event' do
          task.update(name: 'some-new-name', state: TaskModel::FAILED_STATE)

          event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
          expect(event).to be_nil
        end
      end
    end

    describe 'after destroy' do
      let(:task) { TaskModel.make(app: parent_app, state: TaskModel::PENDING_STATE) }

      it 'creates a TASK_STOPPED event' do
        task.destroy

        event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
        expect(event).not_to be_nil
        expect(event.task_guid).to eq(task.guid)
        expect(event.parent_app_guid).to eq(task.app.guid)
      end

      context 'when the task is already in a terminal state (and thus already has a stop event)' do
        describe 'when the task is failed' do
          let(:task) { TaskModel.make(app: parent_app, state: TaskModel::FAILED_STATE) }

          it 'does not create an additional stop event' do
            task.destroy
            expect(AppUsageEvent.where(task_guid: task.guid, state: 'TASK_STOPPED').count).to eq 0
          end
        end

        describe 'when the task is succeeded' do
          let(:task) { TaskModel.make(app: parent_app, state: TaskModel::SUCCEEDED_STATE) }

          it 'does not create an additional stop event' do
            task.destroy
            expect(AppUsageEvent.where(task_guid: task.guid, state: 'TASK_STOPPED').count).to eq 0
          end
        end
      end
    end

    describe '#run_action_user' do
      let(:task) { TaskModel.make(app: parent_app, droplet: droplet, state: TaskModel::SUCCEEDED_STATE) }
      let(:droplet) { DropletModel.make(app: parent_app) }

      context 'when the task belongs to a CNB lifecycle app' do
        let(:parent_app) { AppModel.make(:cnb) }
        let(:task) { TaskModel.make(app: parent_app, droplet: droplet, state: TaskModel::SUCCEEDED_STATE) }
        let(:droplet) { DropletModel.make(:cnb, app: parent_app) }

        context 'when the task has a user specified' do
          before do
            task.update(user: 'TestUser')
          end

          it 'returns the user' do
            expect(task.run_action_user).to eq('TestUser')
          end
        end

        context 'when the task does not have a user specified' do
          before do
            task.update(user: nil)
          end

          it 'defaults the user to root' do
            expect(task.run_action_user).to eq('root')
          end
        end
      end

      context 'when the task belongs to a Docker lifecycle app' do
        let(:parent_app) { AppModel.make(:docker) }
        let(:task) { TaskModel.make(app: parent_app, droplet: droplet, state: TaskModel::SUCCEEDED_STATE) }
        let(:droplet) { DropletModel.make(:docker, app: parent_app) }
        let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"],"user":"some-user"}' }

        before do
          task.droplet.update(execution_metadata: droplet_execution_metadata)
        end

        context 'when the task has a user specified' do
          before do
            task.update(user: 'ContainerUser')
          end

          it 'returns the user' do
            expect(task.run_action_user).to eq('ContainerUser')
          end
        end

        context 'when the droplet execution metadata specifies a user' do
          it 'returns the specified user' do
            expect(task.run_action_user).to eq('some-user')
          end
        end

        context 'when the droplet execution metadata DOES NOT specify a user' do
          let(:droplet_execution_metadata) { '{"entrypoint":["/image-entrypoint.sh"]}' }

          it 'defaults the user to root' do
            expect(task.run_action_user).to eq('root')
          end
        end

        context 'when the droplet execution metadata is an empty string' do
          let(:droplet_execution_metadata) { '' }

          it 'defaults the user to root' do
            expect(task.run_action_user).to eq('root')
          end
        end

        context 'when the droplet execution metadata is nil' do
          let(:droplet_execution_metadata) { nil }

          it 'defaults the user to root' do
            expect(task.run_action_user).to eq('root')
          end
        end

        context 'when the droplet execution metadata has invalid json' do
          let(:droplet_execution_metadata) { '{' }

          it 'defaults the user to root' do
            expect(task.run_action_user).to eq('root')
          end
        end
      end

      context 'when the task DOES NOT belong to a Docker lifecycle app' do
        context 'when the task has a user specified' do
          before do
            task.update(user: 'ContainerUser')
          end

          it 'returns the user' do
            expect(task.run_action_user).to eq('ContainerUser')
          end
        end

        context 'when the task DOES NOT have a user specified' do
          it 'returns the default "vcap" user' do
            expect(task.run_action_user).to eq('vcap')
          end

          context 'when there is no droplet for the task' do
            before do
              task.droplet.delete
              task.reload
            end

            it 'returns vcap' do
              expect(task.run_action_user).to eq('vcap')
            end
          end
        end
      end
    end

    describe 'docker?' do
      context 'when there is a droplet and it has the docker lifecycle' do
        let(:parent_app) { AppModel.make(:docker) }
        let(:task) { TaskModel.make(app: parent_app, droplet: droplet, state: TaskModel::SUCCEEDED_STATE) }
        let(:droplet) { DropletModel.make(:docker, app: parent_app) }

        it 'returns true' do
          expect(task.docker?).to be(true)
        end
      end

      context 'when there is a droplet and it does not have the docker lifecycle' do
        let(:parent_app) { AppModel.make(:docker) }
        let(:task) { TaskModel.make(app: parent_app, droplet: droplet, state: TaskModel::SUCCEEDED_STATE) }
        let(:droplet) { DropletModel.make(:buildpack, app: parent_app) }

        it 'returns false' do
          expect(task.docker?).to be(false)
        end
      end

      context 'when there is not a droplet for the task' do
        let(:parent_app) { AppModel.make(:docker) }
        let(:task) { TaskModel.make(app: parent_app, droplet: droplet, state: TaskModel::SUCCEEDED_STATE) }
        let(:droplet) { DropletModel.make(:docker, app: parent_app) }

        before do
          task.droplet.delete
          task.reload
        end

        it 'returns false' do
          expect(task.docker?).to be(false)
        end
      end
    end

    describe 'cnb?' do
      context 'when there is a droplet and it has the cnb lifecycle' do
        let(:parent_app) { AppModel.make(:cnb) }
        let(:task) { TaskModel.make(app: parent_app, droplet: droplet, state: TaskModel::SUCCEEDED_STATE) }
        let(:droplet) { DropletModel.make(:cnb, app: parent_app) }

        it 'returns true' do
          expect(task.cnb?).to be(true)
        end
      end

      context 'when there is a droplet and it does not have the cnb lifecycle' do
        let(:parent_app) { AppModel.make(:cnb) }
        let(:task) { TaskModel.make(app: parent_app, droplet: droplet, state: TaskModel::SUCCEEDED_STATE) }
        let(:droplet) { DropletModel.make(:buildpack, app: parent_app) }

        it 'returns false' do
          expect(task.cnb?).to be(false)
        end
      end

      context 'when there is not a droplet for the task' do
        let(:parent_app) { AppModel.make(:cnb) }
        let(:task) { TaskModel.make(app: parent_app, droplet: droplet, state: TaskModel::SUCCEEDED_STATE) }
        let(:droplet) { DropletModel.make(:cnb, app: parent_app) }

        before do
          task.droplet.delete
          task.reload
        end

        it 'returns false' do
          expect(task.cnb?).to be(false)
        end
      end
    end

    describe 'validations' do
      let(:task) { TaskModel.make }
      let(:org) { Organization.make }
      let(:space) { Space.make organization: org }
      let(:app) { AppModel.make space_guid: space.guid }
      let(:droplet) { DropletModel.make(app_guid: app.guid) }

      describe 'name' do
        it 'allows standard ascii characters' do
          task.name = "A -_- word 2!?()'\"&+."
          expect do
            task.save
          end.not_to raise_error
        end

        it 'allows backslash characters' do
          task.name = 'a \\ word'
          expect do
            task.save
          end.not_to raise_error
        end

        it 'allows unicode characters' do
          task.name = '詩子¡'
          expect do
            task.save
          end.not_to raise_error
        end

        it 'does not allow newline characters' do
          task.name = "a \n word"
          expect do
            task.save
          end.to raise_error(Sequel::ValidationFailed)
        end

        it 'does not allow escape characters' do
          task.name = "a \e word"
          expect do
            task.save
          end.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe 'state' do
        it 'can be RUNNING' do
          task.state = 'RUNNING'
          expect(task).to be_valid
        end

        it 'can be FAILED' do
          task.state = 'FAILED'
          expect(task).to be_valid
        end

        it 'can be CANCELING' do
          task.state = 'CANCELING'
          expect(task).to be_valid
        end

        it 'can be SUCCEEDED' do
          task.state = 'SUCCEEDED'
          expect(task).to be_valid
        end

        it 'can be PENDING' do
          task.state = 'PENDING'
          expect(task).to be_valid
        end

        it 'can not be something else' do
          task.state = 'SOMETHING ELSE'
          expect(task).not_to be_valid
        end
      end

      describe 'command' do
        it 'can be <= 4096 characters' do
          task.command = 'a' * 4096
          expect(task).to be_valid
        end

        it 'cannot be > 4096 characters' do
          task.command = 'a' * 4097
          expect(task).not_to be_valid
          expect(task.errors.full_messages).to include('command must be shorter than 4097 characters')
        end
      end

      describe 'sequence_id' do
        it 'can be set to an integer' do
          task.sequence_id = 1
          expect(task).to be_valid
        end

        it 'is unique per app' do
          task.sequence_id = 0
          task.save

          expect do
            TaskModel.make app: task.app, sequence_id: 0
          end.to raise_exception Sequel::UniqueConstraintViolation
        end

        it 'is NOT unique across different apps' do
          task.sequence_id = 0
          task.save

          other_app = AppModel.make space_guid: space.guid

          expect do
            TaskModel.make app: other_app, sequence_id: 0
          end.not_to raise_exception
        end
      end

      describe 'environment_variables' do
        it 'validates them' do
          expect do
            TaskModel.make(environment_variables: '')
          end.to raise_error(Sequel::ValidationFailed, /must be an object/)
        end

        context 'maximum length allow' do
          before do
            stub_const('VCAP::CloudController::TaskModel::ENV_VAR_MAX_LENGTH', 5)
          end

          it 'limits the length' do
            expect do
              TaskModel.make(environment_variables: { 123 => 123 }).save
            end.to raise_error(Sequel::ValidationFailed, /exceeded the maximum length allowed of 5 characters as json/)
          end
        end
      end

      describe 'presence' do
        it 'must have an app' do
          expect do
            TaskModel.make(name: 'name',
                           droplet: droplet,
                           app: nil,
                           command: 'bundle exec rake db:migrate')
          end.to raise_error(Sequel::ValidationFailed, /app presence/)
        end

        it 'must have a command' do
          expect do
            TaskModel.make(name: 'name',
                           droplet: droplet,
                           app: app,
                           command: nil)
          end.to raise_error(Sequel::ValidationFailed, /command presence/)
        end

        context 'droplet' do
          context 'when creating the task' do
            it 'must have a droplet' do
              expect do
                TaskModel.make(name: 'name',
                               droplet: nil,
                               app: app,
                               command: 'bundle exec rake db:migrate')
              end.to raise_error(Sequel::ValidationFailed, /droplet presence/)
            end
          end

          context 'when updating the task' do
            it 'does not need a droplet' do
              task = TaskModel.make(name: 'name',
                                    droplet: droplet,
                                    app: app,
                                    command: 'bundle exec rake db:migrate')

              droplet.delete
              task.reload
              expect { task.update(state: 'FAILED') }.not_to raise_error
            end
          end
        end

        it 'must have a name' do
          expect do
            TaskModel.make(name: nil,
                           droplet: droplet,
                           app: app,
                           command: 'bundle exec rake db:migrate')
          end.to raise_error(Sequel::ValidationFailed, /name presence/)
        end
      end

      describe 'quotas' do
        it 'errors when log_rate_limit is below -1' do
          expect do
            TaskModel.make(
              log_rate_limit: -2,
              app: app
            )
          end.to raise_error(Sequel::ValidationFailed, /log_rate_limit must be greater than or equal to -1/)
        end

        describe 'space quotas' do
          let(:space) { Space.make organization: org, space_quota_definition: quota }

          context 'when there is no quota' do
            let(:quota) { nil }

            it 'allows tasks of any size' do
              expect do
                TaskModel.make(
                  memory_in_mb: 21,
                  app: app
                )
              end.not_to raise_error
            end
          end

          describe 'when the log rate limit quota is unlimited' do
            let(:quota) { SpaceQuotaDefinition.make(log_rate_limit: -1, organization: org) }

            it 'allows tasks to run with unlimited rate limits' do
              expect do
                TaskModel.make(
                  log_rate_limit: -1,
                  app: app
                )
              end.not_to raise_error
            end

            it 'allows tasks to run with rate limits' do
              expect do
                TaskModel.make(
                  log_rate_limit: 1_000_000_000_000,
                  app: app
                )
              end.not_to raise_error
            end
          end

          describe 'when the quota has a log_rate_limit' do
            let(:quota) { SpaceQuotaDefinition.make(log_rate_limit: 200, organization: org) }

            it 'allows tasks that fit in the available log rate' do
              expect do
                TaskModel.make(
                  log_rate_limit: 100,
                  app: app
                )
              end.not_to raise_error
            end

            it 'raises an error if the task does not fit in the remaining space' do
              expect do
                TaskModel.make(
                  log_rate_limit: 201,
                  app: app
                )
              end.to raise_error Sequel::ValidationFailed, 'log_rate_limit exceeds space log rate quota'
            end

            it 'raises an error if the task has an unlimited rate limit' do
              expect do
                TaskModel.make(
                  log_rate_limit: -1,
                  app: app
                )
              end.to raise_error Sequel::ValidationFailed, "log_rate_limit cannot be unlimited in space '#{space.name}'."
            end
          end

          describe 'when the quota has a memory_limit' do
            let(:quota) { SpaceQuotaDefinition.make(memory_limit: 20, organization: org) }

            it 'allows tasks that fit in the available space' do
              expect do
                TaskModel.make(
                  memory_in_mb: 10,
                  app: app
                )
              end.not_to raise_error
            end

            it 'raises an error if the task does not fit in the remaining space' do
              expect do
                TaskModel.make(
                  memory_in_mb: 21,
                  app: app
                )
              end.to raise_error Sequel::ValidationFailed, 'memory_in_mb exceeds space memory quota'
            end

            it 'does not raise errors when canceling task above quota' do
              task = TaskModel.make(memory_in_mb: 10, app: app)
              space.update(space_quota_definition: SpaceQuotaDefinition.make(memory_limit: 5, organization: org))

              task.update(state: TaskModel::CANCELING_STATE)
              expect(task.reload).to be_valid
            end
          end

          describe 'when the quota has an instance_memory_limit' do
            let(:quota) { SpaceQuotaDefinition.make(instance_memory_limit: 2, organization: org) }

            it 'allows tasks that fit in the instance memory limit' do
              expect do
                TaskModel.make(
                  memory_in_mb: 1,
                  app: app
                )
              end.not_to raise_error
            end

            it 'raises an error if the task is larger than the instance memory limit' do
              expect do
                TaskModel.make(
                  memory_in_mb: 3,
                  app: app
                )
              end.to raise_error Sequel::ValidationFailed, 'memory_in_mb exceeds space instance memory quota'
            end

            context 'when the quota is unlimited' do
              let(:quota) { SpaceQuotaDefinition.make(instance_memory_limit: QuotaDefinition::UNLIMITED, organization: org) }

              it 'allows tasks of all sizes' do
                expect do
                  TaskModel.make(
                    memory_in_mb: 500,
                    app: app
                  )
                end.not_to raise_error
              end
            end
          end

          describe 'user' do
            subject(:task) { TaskModel.make(user: task_user) }
            let(:task_user) { 'vcap' }

            before do
              TestConfig.override(additional_allowed_process_users: %w[some_user some_other_user])
            end

            context 'when user is vcap' do
              before do
                TestConfig.override(additional_allowed_process_users: [])
              end

              it 'is always permitted' do
                expect { task.save }.not_to raise_error
              end
            end

            context 'when user is a permitted user' do
              let(:task_user) { 'some_user' }

              it 'does not raise an error' do
                expect { task.save }.not_to raise_error
              end
            end

            context 'when user is nil' do
              let(:task_user) { nil }

              it 'does not raise an error' do
                expect { task.save }.not_to raise_error
              end
            end

            context 'when user is not permitted' do
              let(:task_user) { 'some-random-user' }

              it 'raises an error' do
                expect { task.save }.to raise_error(/user invalid/)
              end
            end
          end

          describe 'when the quota has an app_task_limit' do
            let(:quota) { SpaceQuotaDefinition.make(app_task_limit: 1, organization: org) }

            it 'allows tasks that is within app tasks limit' do
              expect { TaskModel.make(app:) }.not_to raise_error
            end

            it 'allows tasks to be updated if the limit is reached' do
              task = TaskModel.make(app: app, state: TaskModel::PENDING_STATE)

              task.state = TaskModel::RUNNING_STATE

              expect { task.save }.not_to raise_error
            end

            context 'when the number of running tasks is equal to the app task limit' do
              before do
                TaskModel.make(state: TaskModel::RUNNING_STATE, app: app)
              end

              it 'raises an error' do
                expect { TaskModel.make(app:) }.to raise_error Sequel::ValidationFailed, 'app_task_limit quota exceeded'
              end
            end
          end
        end

        describe 'org quotas' do
          let(:org) { Organization.make quota_definition: quota }

          context 'when there is no quota' do
            let(:quota) { nil }

            it 'allows tasks of any size' do
              expect do
                TaskModel.make(
                  memory_in_mb: 21,
                  log_rate_limit: 21_000,
                  app: app
                )
              end.not_to raise_error
            end
          end

          describe 'when the quota has a log_rate_limit' do
            let(:quota) { QuotaDefinition.make(log_rate_limit: 200) }

            it 'does allow a task that fits in the limit to start' do
              expect do
                TaskModel.make(
                  log_rate_limit: 199,
                  app: app
                )
              end.not_to raise_error
            end

            it 'does not allow a task that exceeds the limit to start' do
              expect do
                TaskModel.make(
                  log_rate_limit: 10_000,
                  app: app
                )
              end.to raise_error(/log_rate_limit exceeds organization log rate/)
            end
          end

          describe 'when the quota has a memory_limit' do
            let(:quota) { QuotaDefinition.make(memory_limit: 20) }

            it 'allows tasks that fit in the available space' do
              expect do
                TaskModel.make(
                  memory_in_mb: 10,
                  app: app
                )
              end.not_to raise_error
            end

            it 'raises an error if the task does not fit in the remaining space' do
              expect do
                TaskModel.make(
                  memory_in_mb: 21,
                  app: app
                )
              end.to raise_error Sequel::ValidationFailed, 'memory_in_mb exceeds organization memory quota'
            end

            it 'does not raise errors when canceling task above quota' do
              task = TaskModel.make(memory_in_mb: 10, app: app)
              org.update(quota_definition: QuotaDefinition.make(memory_limit: 5))

              task.update(state: TaskModel::CANCELING_STATE)
              expect(task.reload).to be_valid
            end
          end

          describe 'when the quota has an instance_memory_limit' do
            let(:quota) { QuotaDefinition.make(instance_memory_limit: 2) }

            it 'allows tasks that fit in the instance memory limit' do
              expect do
                TaskModel.make(
                  memory_in_mb: 1,
                  app: app
                )
              end.not_to raise_error
            end

            it 'raises an error if the task is larger than the instance memory limit' do
              expect do
                TaskModel.make(
                  memory_in_mb: 3,
                  app: app
                )
              end.to raise_error Sequel::ValidationFailed, 'memory_in_mb exceeds organization instance memory quota'
            end

            context 'when the quota is unlimited' do
              let(:quota) { QuotaDefinition.make(instance_memory_limit: QuotaDefinition::UNLIMITED) }

              it 'allows tasks of all sizes' do
                expect do
                  TaskModel.make(
                    memory_in_mb: 500,
                    app: app
                  )
                end.not_to raise_error
              end
            end
          end

          describe 'when the quota has an app_task_limit' do
            let(:quota) { QuotaDefinition.make(app_task_limit: 1) }

            it 'allows tasks that is within app tasks limit' do
              expect { TaskModel.make(app:) }.not_to raise_error
            end

            it 'allows tasks to be updated if the limit is reached' do
              task = TaskModel.make(app: app, state: TaskModel::PENDING_STATE)

              task.state = TaskModel::RUNNING_STATE

              expect { task.save }.not_to raise_error
            end

            context 'when the number of running tasks is equal to the app task limit' do
              before do
                TaskModel.make(state: TaskModel::RUNNING_STATE, app: app)
              end

              it 'raises an error' do
                expect { TaskModel.make(app:) }.to raise_error Sequel::ValidationFailed, 'app_task_limit quota exceeded'
              end
            end
          end
        end
      end
    end
  end
end
