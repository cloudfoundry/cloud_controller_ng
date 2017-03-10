require 'spec_helper'
require 'actions/task_create'

module VCAP::CloudController
  RSpec.describe TaskCreate do
    subject(:task_create_action) { described_class.new(config) }
    let(:config) { { maximum_app_disk_in_mb: 4096 } }

    describe '#create' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:droplet) { DropletModel.make(app_guid: app.guid, state: DropletModel::STAGED_STATE) }
      let(:command) { 'bundle exec rake panda' }
      let(:name) { 'my_task_name' }
      let(:message) { TaskCreateMessage.new name: name, command: command, disk_in_mb: 2048, memory_in_mb: 1024 }
      let(:client) { instance_double(VCAP::CloudController::Diego::NsyncClient) }
      let(:bbs_client) { instance_double(VCAP::CloudController::Diego::BbsTaskClient) }
      let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }

      before do
        locator = CloudController::DependencyLocator.instance
        allow(locator).to receive(:nsync_client).and_return(client)
        allow(locator).to receive(:bbs_task_client).and_return(bbs_client)
        allow(client).to receive(:desire_task).and_return(nil)
        allow(bbs_client).to receive(:desire_task).and_return(nil)

        app.droplet = droplet
        app.save
      end

      it 'creates and returns a task using the given app and its droplet' do
        task = task_create_action.create(app, message, user_audit_info)

        expect(task.app).to eq(app)
        expect(task.droplet).to eq(droplet)
        expect(task.command).to eq(command)
        expect(task.name).to eq(name)
        expect(task.disk_in_mb).to eq(2048)
        expect(task.memory_in_mb).to eq(1024)
        expect(TaskModel.count).to eq(1)
      end

      it "sets the task state to 'PENDING'" do
        task = task_create_action.create(app, message, user_audit_info)

        expect(task.state).to eq(TaskModel::PENDING_STATE)
      end

      describe 'desiring the task from Diego' do
        context 'when using the bridge' do
          it 'tells nsync to make the task' do
            task = task_create_action.create(app, message, user_audit_info)

            expect(client).to have_received(:desire_task).with(task)
          end
        end

        context 'when talking directly to BBS' do
          let(:task_definition) { instance_double(::Diego::Bbs::Models::TaskDefinition) }
          let(:recipe_builder) { instance_double(Diego::TaskRecipeBuilder) }

          before do
            config[:diego] = {
              temporary_local_tasks: true
            }
            allow(recipe_builder).to receive(:build_app_task).with(config, instance_of(TaskModel)).and_return(task_definition)
            allow(Diego::TaskRecipeBuilder).to receive(:new).and_return(recipe_builder)
          end

          it 'builds a recipe for the task and desires the task from BBS' do
            task = task_create_action.create(app, message, user_audit_info)

            expect(bbs_client).to have_received(:desire_task).with(task.guid, task_definition, Diego::TASKS_DOMAIN)
          end

          it 'updates the task to be running' do
            task = task_create_action.create(app, message, user_audit_info)

            expect(task.state).to eq(TaskModel::RUNNING_STATE)
          end

          describe 'task errors' do
            it 'catches InvalidDownloadUri and wraps it in an API error' do
              allow(recipe_builder).to receive(:build_app_task).and_raise(Diego::Buildpack::LifecycleProtocol::InvalidDownloadUri.new('error message'))
              expect {
                task_create_action.create(app, message, user_audit_info)
              }.to raise_error CloudController::Errors::ApiError, /Task failed: error message/
            end

            describe 'lifecycle bundle errors from recipe builder' do
              it 'catches InvalidStack and wraps it in an API error' do
                allow(recipe_builder).to receive(:build_app_task).and_raise(Diego::LifecycleBundleUriGenerator::InvalidStack.new('error message'))
                expect {
                  task_create_action.create(app, message, user_audit_info)
                }.to raise_error CloudController::Errors::ApiError, /Task failed: error message/
              end

              it 'catches InvalidCompiler and wraps it in an API error' do
                allow(recipe_builder).to receive(:build_app_task).and_raise(Diego::LifecycleBundleUriGenerator::InvalidCompiler.new('error message'))
                expect {
                  task_create_action.create(app, message, user_audit_info)
                }.to raise_error CloudController::Errors::ApiError, /Task failed: error message/
              end
            end

            context 'when the bbs task client throws an error' do
              let(:error) { CloudController::Errors::ApiError.new }
              before { allow(bbs_client).to receive(:desire_task).and_raise(error) }

              it 'marks the task as failed and re-raises' do
                expect(TaskModel.count).to eq(0)
                expect {
                  task_create_action.create(app, message, user_audit_info)
                }.to raise_error(error)

                task = TaskModel.first
                expect(task.state).to eq(TaskModel::FAILED_STATE)
              end
            end
          end
        end
      end

      it 'creates an app usage event for TASK_STARTED' do
        task = task_create_action.create(app, message, user_audit_info)

        event = AppUsageEvent.last
        expect(event.state).to eq('TASK_STARTED')
        expect(event.task_guid).to eq(task.guid)
      end

      it 'creates a task create audit event' do
        task = task_create_action.create(app, message, user_audit_info)

        event = Event.last
        expect(event.type).to eq('audit.app.task.create')
        expect(event.metadata['task_guid']).to eq(task.guid)
        expect(event.actee).to eq(app.guid)
      end

      describe 'sequence id' do
        it 'gives the task a sequence id' do
          task = task_create_action.create(app, message, user_audit_info)

          expect(task.sequence_id).to eq(1)
        end

        it 'increments the sequence id for each task' do
          expect(task_create_action.create(app, message, user_audit_info).sequence_id).to eq(1)
          app.reload
          expect(task_create_action.create(app, message, user_audit_info).sequence_id).to eq(2)
          app.reload
          expect(task_create_action.create(app, message, user_audit_info).sequence_id).to eq(3)
        end

        it 'does not re-use task ids from deleted tasks' do
          task_create_action.create(app, message, user_audit_info)
          app.reload
          task_create_action.create(app, message, user_audit_info)
          app.reload
          task = task_create_action.create(app, message, user_audit_info)
          task.delete
          app.reload
          expect(task_create_action.create(app, message, user_audit_info).sequence_id).to eq(4)
        end
      end

      describe 'default values' do
        let(:message) { TaskCreateMessage.new name: name, command: command }

        before { config[:default_app_memory] = 200 }

        it 'sets disk_in_mb to configured :default_app_disk_in_mb' do
          config[:default_app_disk_in_mb] = 200

          task = task_create_action.create(app, message, user_audit_info)

          expect(task.disk_in_mb).to eq(200)
        end

        it 'sets memory_in_mb to configured :default_app_memory' do
          task = task_create_action.create(app, message, user_audit_info)

          expect(task.memory_in_mb).to eq(200)
        end
      end

      context 'when the app does not have an assigned droplet' do
        let(:app_with_no_droplet) { AppModel.make }

        it 'raises a NoAssignedDroplet error' do
          expect {
            task_create_action.create(app_with_no_droplet, message, user_audit_info)
          }.to raise_error(TaskCreate::NoAssignedDroplet, 'Task must have a droplet. Specify droplet or assign current droplet to app.')
        end
      end

      context 'when the name is not requested' do
        let(:message) { TaskCreateMessage.new command: command, memory_in_mb: 1024 }

        it 'uses a hex string as the name' do
          task = task_create_action.create(app, message, user_audit_info)
          expect(task.name).to match /^[0-9a-f]{8}$/
        end
      end

      context 'when the task is invalid' do
        before do
          allow_any_instance_of(TaskModel).to receive(:save).and_raise(Sequel::ValidationFailed.new('booooooo'))
        end

        it 'raises an InvalidTask error' do
          expect {
            task_create_action.create(app, message, user_audit_info)
          }.to raise_error(TaskCreate::InvalidTask, 'booooooo')
        end
      end

      context 'when a custom droplet is specified' do
        let(:custom_droplet) { DropletModel.make(app_guid: app.guid, state: DropletModel::STAGED_STATE) }

        it 'creates the task with the specified droplet' do
          task = task_create_action.create(app, message, user_audit_info, droplet: custom_droplet)

          expect(task.droplet).to eq(custom_droplet)
        end
      end

      context 'when the requested disk in mb is higher than the configured maximum' do
        let(:config) { { maximum_app_disk_in_mb: 10 } }

        it 'raises an error' do
          expect {
            task_create_action.create(app, message, user_audit_info)
          }.to raise_error(TaskCreate::MaximumDiskExceeded, /Cannot request disk_in_mb greater than 10/)
        end
      end
    end
  end
end
