require 'spec_helper'

module VCAP::CloudController
  RSpec.describe TaskModel do
    let(:parent_app) { AppModel.make }

    describe 'after create' do
      it 'creates a TASK_STARTED event' do
        task = TaskModel.make(app: parent_app, state: TaskModel::PENDING_STATE)

        event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STARTED')
        expect(event).not_to be_nil
        expect(event.task_guid).to eq(task.guid)
        expect(event.parent_app_guid).to eq(task.app.guid)
      end
    end

    describe 'after update' do
      let(:task) { TaskModel.make(app: parent_app, state: TaskModel::PENDING_STATE) }

      context 'when the task is moving to SUCCEEDED_STATE' do
        it 'creates a TASK_STOPPED event' do
          task.update(state: TaskModel::SUCCEEDED_STATE)

          event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
          expect(event).not_to be_nil
          expect(event.task_guid).to eq(task.guid)
          expect(event.parent_app_guid).to eq(task.app.guid)
        end
      end

      context 'when the task is moving to FAILED_STATE' do
        it 'creates a TASK_STOPPED event' do
          task.update(state: TaskModel::FAILED_STATE)

          event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
          expect(event).not_to be_nil
          expect(event.task_guid).to eq(task.guid)
          expect(event.parent_app_guid).to eq(task.app.guid)
        end
      end

      context 'when the task is moving to RUNNING_STATE' do
        it 'does not create a TASK_STOPPED event' do
          task.update(state: TaskModel::RUNNING_STATE)

          event = AppUsageEvent.find(task_guid: task.guid, state: 'TASK_STOPPED')
          expect(event).to be_nil
        end
      end

      context 'when the state is not changing' do
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

    describe 'validations' do
      let(:task) { TaskModel.make }
      let(:org) { Organization.make }
      let(:space) { Space.make organization: org }
      let(:app) { AppModel.make space_guid: space.guid }
      let(:droplet) { DropletModel.make(app_guid: app.guid) }

      describe 'name' do
        it 'should allow standard ascii characters' do
          task.name = "A -_- word 2!?()\'\"&+."
          expect {
            task.save
          }.to_not raise_error
        end

        it 'should allow backslash characters' do
          task.name = 'a \\ word'
          expect {
            task.save
          }.to_not raise_error
        end

        it 'should allow unicode characters' do
          task.name = '詩子¡'
          expect {
            task.save
          }.to_not raise_error
        end

        it 'should not allow newline characters' do
          task.name = "a \n word"
          expect {
            task.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow escape characters' do
          task.name = "a \e word"
          expect {
            task.save
          }.to raise_error(Sequel::ValidationFailed)
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
          expect(task).to_not be_valid
        end
      end

      describe 'command' do
        it 'can be <= 4096 characters' do
          task.command = 'a' * 4096
          expect(task).to be_valid
        end

        it 'cannot be > 4096 characters' do
          task.command = 'a' * 4097
          expect(task).to_not be_valid
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

          expect {
            TaskModel.make app: task.app, sequence_id: 0
          }.to raise_exception Sequel::UniqueConstraintViolation
        end

        it 'is NOT unique across different apps' do
          task.sequence_id = 0
          task.save

          other_app = AppModel.make space_guid: space.guid

          expect {
            TaskModel.make app: other_app, sequence_id: 0
          }.to_not raise_exception
        end
      end

      describe 'environment_variables' do
        it 'validates them' do
          expect {
            TaskModel.make(environment_variables: '')
          }.to raise_error(Sequel::ValidationFailed, /must be a hash/)
        end

        context 'maximum length allow' do
          before do
            stub_const('VCAP::CloudController::TaskModel::ENV_VAR_MAX_LENGTH', 5)
          end

          it 'limits the length' do
            expect {
              TaskModel.make(environment_variables: { 123 => 123 }).save
            }.to raise_error(Sequel::ValidationFailed, /exceeded the maximum length allowed of 5 characters as json/)
          end
        end
      end

      describe 'presence' do
        it 'must have an app' do
          expect { TaskModel.make(name: 'name',
                                  droplet: droplet,
                                  app: nil,
                                  command: 'bundle exec rake db:migrate')
          }.to raise_error(Sequel::ValidationFailed, /app presence/)
        end

        it 'must have a command' do
          expect { TaskModel.make(name: 'name',
                                  droplet: droplet,
                                  app: app,
                                  command: nil)
          }.to raise_error(Sequel::ValidationFailed, /command presence/)
        end

        it 'must have a droplet' do
          expect { TaskModel.make(name: 'name',
                                  droplet: nil,
                                  app: app,
                                  command: 'bundle exec rake db:migrate')
          }.to raise_error(Sequel::ValidationFailed, /droplet presence/)
        end

        it 'must have a name' do
          expect { TaskModel.make(name: nil,
                                  droplet: droplet,
                                  app: app,
                                  command: 'bundle exec rake db:migrate')
          }.to raise_error(Sequel::ValidationFailed, /name presence/)
        end
      end

      describe 'quotas' do
        describe 'space quotas' do
          let(:space) { Space.make organization: org, space_quota_definition: quota }

          context 'when there is no quota' do
            let(:quota) { nil }

            it 'allows tasks of any size' do
              expect {
                TaskModel.make(
                  memory_in_mb: 21,
                  app: app,
                )
              }.not_to raise_error
            end
          end

          describe 'when the quota has a memory_limit' do
            let(:quota) { SpaceQuotaDefinition.make(memory_limit: 20, organization: org) }

            it 'allows tasks that fit in the available space' do
              expect {
                TaskModel.make(
                  memory_in_mb: 10,
                  app: app,
                )
              }.not_to raise_error
            end

            it 'raises an error if the task does not fit in the remaining space' do
              expect {
                TaskModel.make(
                  memory_in_mb: 21,
                  app: app,
                )
              }.to raise_error Sequel::ValidationFailed, 'memory_in_mb exceeds space memory quota'
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
              expect {
                TaskModel.make(
                  memory_in_mb: 1,
                  app: app,
                )
              }.not_to raise_error
            end

            it 'raises an error if the task is larger than the instance memory limit' do
              expect {
                TaskModel.make(
                  memory_in_mb: 3,
                  app: app,
                )
              }.to raise_error Sequel::ValidationFailed, 'memory_in_mb exceeds space instance memory quota'
            end

            context 'when the quota is unlimited' do
              let(:quota) { SpaceQuotaDefinition.make(instance_memory_limit: QuotaDefinition::UNLIMITED, organization: org) }

              it 'allows tasks of all sizes' do
                expect {
                  TaskModel.make(
                    memory_in_mb: 500,
                    app: app,
                  )
                }.not_to raise_error
              end
            end
          end

          describe 'when the quota has an app_task_limit' do
            let(:quota) { SpaceQuotaDefinition.make(app_task_limit: 1, organization: org) }

            it 'allows tasks that is within app tasks limit' do
              expect { TaskModel.make(app: app) }.not_to raise_error
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
                expect { TaskModel.make(app: app) }.to raise_error Sequel::ValidationFailed, 'app_task_limit quota exceeded'
              end
            end
          end
        end

        describe 'org quotas' do
          let(:org) { Organization.make quota_definition: quota }

          context 'when there is no quota' do
            let(:quota) { nil }

            it 'allows tasks of any size' do
              expect {
                TaskModel.make(
                  memory_in_mb: 21,
                  app: app,
                )
              }.not_to raise_error
            end
          end

          describe 'when the quota has a memory_limit' do
            let(:quota) { QuotaDefinition.make(memory_limit: 20) }

            it 'allows tasks that fit in the available space' do
              expect {
                TaskModel.make(
                  memory_in_mb: 10,
                  app: app,
                )
              }.not_to raise_error
            end

            it 'raises an error if the task does not fit in the remaining space' do
              expect {
                TaskModel.make(
                  memory_in_mb: 21,
                  app: app,
                )
              }.to raise_error Sequel::ValidationFailed, 'memory_in_mb exceeds organization memory quota'
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
              expect {
                TaskModel.make(
                  memory_in_mb: 1,
                  app: app,
                )
              }.not_to raise_error
            end

            it 'raises an error if the task is larger than the instance memory limit' do
              expect {
                TaskModel.make(
                  memory_in_mb: 3,
                  app: app,
                )
              }.to raise_error Sequel::ValidationFailed, 'memory_in_mb exceeds organization instance memory quota'
            end

            context 'when the quota is unlimited' do
              let(:quota) { QuotaDefinition.make(instance_memory_limit: QuotaDefinition::UNLIMITED) }

              it 'allows tasks of all sizes' do
                expect {
                  TaskModel.make(
                    memory_in_mb: 500,
                    app: app,
                  )
                }.not_to raise_error
              end
            end
          end

          describe 'when the quota has an app_task_limit' do
            let(:quota) { QuotaDefinition.make(app_task_limit: 1) }

            it 'allows tasks that is within app tasks limit' do
              expect { TaskModel.make(app: app) }.not_to raise_error
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
                expect { TaskModel.make(app: app) }.to raise_error Sequel::ValidationFailed, 'app_task_limit quota exceeded'
              end
            end
          end
        end
      end
    end
  end
end
