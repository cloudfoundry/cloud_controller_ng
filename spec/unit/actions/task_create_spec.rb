require 'spec_helper'
require 'actions/task_create'

module VCAP::CloudController
  RSpec.describe TaskCreate do
    subject(:task_create_action) { TaskCreate.new(config) }
    let(:config) do
      Config.new(
        maximum_app_disk_in_mb: 4096,
        default_app_memory: 1024,
        default_app_disk_in_mb: 1024
      )
    end

    describe '#create' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:droplet) { DropletModel.make(app_guid: app.guid, state: DropletModel::STAGED_STATE, process_types: { 'web' => 'start app' }) }
      let(:command) { 'bundle exec rake panda' }
      let(:name) { 'my_task_name' }
      let(:message) { TaskCreateMessage.new(
        name: name,
        command: command,
        disk_in_mb: 2048,
        memory_in_mb: 1024,
        metadata: {
          labels: {
            release: 'stable',
            'seriouseats.com/potato' => 'mashed'
          },
          annotations: {
            tomorrow: 'land',
            backstreet: 'boys'
          }
        }
      )
      }
      let(:bbs_client) { instance_double(VCAP::CloudController::Diego::BbsTaskClient) }
      let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }

      before do
        locator = CloudController::DependencyLocator.instance
        allow(locator).to receive(:bbs_task_client).and_return(bbs_client)
        allow(bbs_client).to receive(:desire_task).and_return(nil)
        allow_any_instance_of(VCAP::CloudController::Diego::TaskRecipeBuilder).to receive(:build_app_task)

        app.droplet = droplet
        app.save
      end

      it 'creates and returns a task using the given app and its droplet' do
        task = task_create_action.create(app, message, user_audit_info)

        expect(task.app.guid).to eq(app.guid)
        expect(task.droplet).to eq(droplet)
        expect(task.command).to eq(command)
        expect(task.name).to eq(name)
        expect(task.disk_in_mb).to eq(2048)
        expect(task.memory_in_mb).to eq(1024)

        expect(task).to have_labels(
          { prefix: 'seriouseats.com', key: 'potato', value: 'mashed' },
          { prefix: nil, key: 'release', value: 'stable' }
        )
        expect(task).to have_annotations(
          { key: 'tomorrow', value: 'land' },
          { key: 'backstreet', value: 'boys' }
        )

        expect(TaskModel.count).to eq(1)
      end

      it "sets the task state to 'RUNNING'" do
        task = task_create_action.create(app, message, user_audit_info)

        expect(task.state).to eq(TaskModel::RUNNING_STATE)
      end

      describe 'desiring the task from Diego' do
        context 'when talking directly to BBS' do
          it 'builds a recipe for the task and desires the task from BBS' do
            task = task_create_action.create(app, message, user_audit_info)

            expect(bbs_client).to have_received(:desire_task).with(task, Diego::TASKS_DOMAIN)
          end

          it 'updates the task to be running' do
            task = task_create_action.create(app, message, user_audit_info)

            expect(task.state).to eq(TaskModel::RUNNING_STATE)
          end

          describe 'task errors' do
            it 'catches InvalidDownloadUri and wraps it in an API error' do
              allow(bbs_client).to receive(:desire_task).and_raise(Diego::Buildpack::LifecycleProtocol::InvalidDownloadUri.new('error message'))
              expect {
                task_create_action.create(app, message, user_audit_info)
              }.to raise_error CloudController::Errors::ApiError, /Task failed: error message/
            end

            describe 'lifecycle bundle errors from recipe builder' do
              it 'catches InvalidStack and wraps it in an API error' do
                allow(bbs_client).to receive(:desire_task).and_raise(Diego::LifecycleBundleUriGenerator::InvalidStack.new('error message'))
                expect {
                  task_create_action.create(app, message, user_audit_info)
                }.to raise_error CloudController::Errors::ApiError, /Task failed: error message/
              end

              it 'catches InvalidCompiler and wraps it in an API error' do
                allow(bbs_client).to receive(:desire_task).and_raise(Diego::LifecycleBundleUriGenerator::InvalidCompiler.new('error message'))
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

      it 'creates a task create audit event' do
        task = task_create_action.create(app, message, user_audit_info)

        event = Event.last
        expect(event).not_to be_nil
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
          task.destroy
          app.reload
          expect(task_create_action.create(app, message, user_audit_info).sequence_id).to eq(4)
        end
      end

      describe 'memory_in_mb' do
        before { config.set(:default_app_memory, 200) }

        context 'when memory_in_mb is not specified' do
          let(:message) { TaskCreateMessage.new name: name, command: command }

          it 'sets memory_in_mb to configured :default_app_memory' do
            task = task_create_action.create(app, message, user_audit_info)

            expect(task.memory_in_mb).to eq(200)
          end
        end

        context 'when memory_in_mb is specified as NULL' do
          let(:message) { TaskCreateMessage.new name: name, command: command, memory_in_mb: nil }

          it 'sets memory_in_mb to configured :default_app_memory' do
            task = task_create_action.create(app, message, user_audit_info)

            expect(task.memory_in_mb).to eq(200)
          end
        end
      end

      describe 'disk_in_mb' do
        before { config.set(:default_app_disk_in_mb, 200) }

        context 'when disk_in_mb is not specified' do
          let(:message) { TaskCreateMessage.new name: name, command: command }

          it 'defaults disk_in_mb to configured :default_app_disk_in_mb' do
            task = task_create_action.create(app, message, user_audit_info)

            expect(task.disk_in_mb).to eq(200)
          end
        end

        context 'when disk_in_mb is specified as NULL' do
          let(:message) { TaskCreateMessage.new name: name, command: command, disk_in_mb: nil }

          it 'sets memory_in_mb to configured :default_app_disk_in_mb' do
            task = task_create_action.create(app, message, user_audit_info)

            expect(task.disk_in_mb).to eq(200)
          end
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
        let(:config) { Config.new({ maximum_app_disk_in_mb: 10 }) }

        it 'raises an error' do
          expect {
            task_create_action.create(app, message, user_audit_info)
          }.to raise_error(TaskCreate::MaximumDiskExceeded, /Cannot request disk_in_mb greater than 10/)
        end
      end

      describe 'process templates' do
        let(:process) { VCAP::CloudController::ProcessModel.make(app: app, command: 'start') }

        describe 'commands' do
          context 'when there is a template and no command provided' do
            let(:message) { TaskCreateMessage.new name: name, disk_in_mb: 2048, memory_in_mb: 1024, template: { process: { guid: process.guid } } }

            it 'uses the command from the template' do
              task = task_create_action.create(app, message, user_audit_info)
              expect(task.command).to eq(process.command)
            end
          end

          context 'when there is a template and a command provided' do
            let(:message) { TaskCreateMessage.new name: name, command: 'justdoit', disk_in_mb: 2048, memory_in_mb: 1024, template: { process: { guid: process.guid } } }

            it 'uses the command provided' do
              task = task_create_action.create(app, message, user_audit_info)
              expect(task.command).to eq('justdoit')
            end
          end

          context 'when the template process has no specified command and the message has no command requested' do
            let(:process) { VCAP::CloudController::ProcessModel.make(app: app, type: 'web') }
            let(:message) { TaskCreateMessage.new name: name, disk_in_mb: 2048, memory_in_mb: 1024, template: { process: { guid: process.guid } } }

            it 'uses the detected command from the process\'s droplet' do
              task = task_create_action.create(app, message, user_audit_info)
              expect(task.command).to eq('start app')
            end
          end
        end

        describe 'memory_in_mb' do
          before do
            config.set(:default_app_memory, 4096)
          end

          context 'when there is a template and the message does NOT specify memory_in_mb' do
            let(:process) { VCAP::CloudController::ProcessModel.make(app: app, type: 'web', memory: 23) }
            let(:message) { TaskCreateMessage.new(name: name, command: 'ok', disk_in_mb: 2048, template: { process: { guid: process.guid } }) }

            it 'uses the memory from the template process' do
              task = task_create_action.create(app, message, user_audit_info)
              expect(task.memory_in_mb).to eq(23)
            end
          end

          context 'when there is a template and the message specifies memory_in_mb' do
            let(:process) { VCAP::CloudController::ProcessModel.make(app: app, type: 'web', memory: 23) }
            let(:message) { TaskCreateMessage.new(name: name, command: 'ok', memory_in_mb: 2048, template: { process: { guid: process.guid } }) }

            it 'uses the memory from the template process' do
              task = task_create_action.create(app, message, user_audit_info)
              expect(task.memory_in_mb).to eq(2048)
            end
          end
        end

        describe 'disk_in_mb' do
          before do
            config.set(:default_app_disk_in_mb, 4096)
          end

          context 'when there is a template and the message does NOT specify disk_in_mb' do
            let(:process) { VCAP::CloudController::ProcessModel.make(app: app, type: 'web', disk_quota: 23) }
            let(:message) { TaskCreateMessage.new(name: name, command: 'ok', memory_in_mb: 2048, template: { process: { guid: process.guid } }) }

            it 'uses the memory from the template process' do
              task = task_create_action.create(app, message, user_audit_info)
              expect(task.disk_in_mb).to eq(23)
            end
          end

          context 'when there is a template and the message specifies disk_in_mb' do
            let(:process) { VCAP::CloudController::ProcessModel.make(app: app, type: 'web', disk_quota: 23) }
            let(:message) { TaskCreateMessage.new(name: name, command: 'ok', disk_in_mb: 2048, template: { process: { guid: process.guid } }) }

            it 'uses the memory from the template process' do
              task = task_create_action.create(app, message, user_audit_info)
              expect(task.disk_in_mb).to eq(2048)
            end
          end
        end
      end
    end
  end
end
