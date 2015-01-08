require 'spec_helper'
require 'handlers/apps_handler'

module VCAP::CloudController
  describe AppsHandler do
    let(:process_handler) { double(:process_handler) }
    let(:apps_handler) { described_class.new(process_handler) }
    let(:access_context) { double(:access_context) }

    before do
      allow(access_context).to receive(:cannot?).and_return(false)
    end

    describe '#list' do
      let(:space) { Space.make }
      let!(:app_model1) { AppModel.make(space_guid: space.guid) }
      let!(:app_model2) { AppModel.make(space_guid: space.guid) }
      let(:user) { User.make }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:pagination_options) { PaginationOptions.new(page, per_page) }
      let(:paginator) { double(:paginator) }
      let(:apps_handler) { described_class.new(process_handler, paginator) }
      let(:roles) { double(:roles, admin?: admin_role) }
      let(:admin_role) { false }

      before do
        allow(access_context).to receive(:roles).and_return(roles)
        allow(access_context).to receive(:user).and_return(user)
        allow(paginator).to receive(:get_page)
      end

      context 'when the user is an admin' do
        let(:admin_role) { true }
        before do
          allow(access_context).to receive(:roles).and_return(roles)
          AppModel.make
        end

        it 'allows viewing all apps' do
          apps_handler.list(pagination_options, access_context)
          expect(paginator).to have_received(:get_page) do |dataset, _|
            expect(dataset.count).to eq(3)
          end
        end
      end

      context 'when the user cannot list any apps' do
        it 'applies a user visibility filter properly' do
          apps_handler.list(pagination_options, access_context)
          expect(paginator).to have_received(:get_page) do |dataset, _|
            expect(dataset.count).to eq(0)
          end
        end
      end

      context 'when the user can list apps' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'applies a user visibility filter properly' do
          apps_handler.list(pagination_options, access_context)
          expect(paginator).to have_received(:get_page) do |dataset, _|
            expect(dataset.count).to eq(2)
          end
        end
      end
    end

    describe '#show' do
      let(:app_model) { AppModel.make }

      context 'when the app does not exist' do
        let(:guid) { 'ABC123' }

        it 'returns nil' do
          result = apps_handler.show(guid, access_context)
          expect(result).to be_nil
        end
      end

      context 'when the app does exist' do
        let(:guid) { app_model.guid }

        context 'when the user cannot access the app' do
          before do
            allow(access_context).to receive(:cannot?).and_return(true)
          end

          it 'returns nil' do
            result = apps_handler.show(guid, access_context)
            expect(result).to be_nil
            expect(access_context).to have_received(:cannot?).with(:read, app_model)
          end
        end

        context 'when the user has access to the app' do
          it 'returns the app' do
            result = apps_handler.show(guid, access_context)
            expect(result).to eq(app_model)
            expect(access_context).to have_received(:cannot?).with(:read, app_model)
          end
        end
      end
    end

    describe '#create' do
      let(:space_guid) { Space.make.guid }
      let(:create_message) { AppCreateMessage.new({ 'name' => 'my_name', 'space_guid' => space_guid }) }

      context 'when the user cannot create an app' do
        before do
          allow(access_context).to receive(:cannot?).and_return(true)
        end

        it 'raises Unauthorized error' do
          expect {
            apps_handler.create(create_message, access_context)
          }.to raise_error(AppsHandler::Unauthorized)
          expect(access_context).to have_received(:cannot?).with(:create, kind_of(AppModel))
        end
      end

      context 'when a user can create a app' do
        it 'creates the app' do
          result = apps_handler.create(create_message, access_context)
          expect(result.name).to eq(create_message.name)
          expect(result.space_guid).to eq(create_message.space_guid)

          created_app = AppModel.find(guid: result.guid)
          expect(created_app.name).to eq(create_message.name)
          expect(created_app.space_guid).to eq(create_message.space_guid)
        end
      end

      context 'when the space does not exist' do
        let(:space_guid) { 'notexist' }

        it 'raises an AppInvalid error' do
          expect {
            apps_handler.create(create_message, access_context)
          }.to raise_error(AppsHandler::InvalidApp, 'Space was not found')
        end

        context 'and the user is not an admin' do
          before do
            # This is to replicate a Space not existing in the access_context
            # check. An access check on an admin user will not attempt to find a
            # Space.
            allow(access_context).to receive(:cannot?).and_return(true)
          end

          it 'still raises an AppInvalid error' do
            expect {
              apps_handler.create(create_message, access_context)
            }.to raise_error(AppsHandler::InvalidApp, 'Space was not found')
          end
        end
      end

      context 'when the app is invalid' do
        before do
          allow_any_instance_of(AppModel).to receive(:save).and_raise(Sequel::ValidationFailed.new('the message'))
        end

        it 'raises an AppInvalid error' do
          expect {
            apps_handler.create(create_message, access_context)
          }.to raise_error(AppsHandler::InvalidApp, 'the message')
        end
      end
    end

    describe '#update' do
      let!(:app_model) { AppModel.make }
      let(:new_name) { 'new-name' }
      let(:guid) { app_model.guid }
      let(:update_message) { AppUpdateMessage.new({ 'guid' => guid, 'name' => new_name }) }
      let(:empty_update_message) { AppUpdateMessage.new({ 'guid' => guid }) }

      context 'when the user cannot update the app' do
        before do
          allow(access_context).to receive(:cannot?).and_return(true)
        end

        it 'raises Unauthorized error' do
          expect {
            apps_handler.update(update_message, access_context)
          }.to raise_error(AppsHandler::Unauthorized)
          expect(access_context).to have_received(:cannot?).with(:update, app_model)
        end
      end

      context 'when the user can update the app' do
        it 'updates the app' do
          result = apps_handler.update(update_message, access_context)
          expect(result.guid).to eq(guid)
          expect(result.name).to eq(new_name)

          updated_app = AppModel.find(guid: guid)
          expect(updated_app.name).to eq(new_name)
        end

        it 'keeps current, non-updated attributes' do
          result = apps_handler.update(empty_update_message, access_context)
          expect(result.guid).to eq(guid)
          expect(result.name).to eq(app_model.name)

          updated_app = AppModel.find(guid: guid)
          expect(updated_app.name).to eq(app_model.name)
        end

        context 'when the app has a web process' do
          let(:space) { Space.find(guid: app_model.space_guid) }
          let(:user) { User.make }
          let(:process_opts) { { space: space } }
          let(:process) { AppFactory.make(process_opts) }
          let(:process_guid) { process.guid }

          before do
            allow(access_context).to receive(:user).and_return(user)
            allow(access_context).to receive(:user_email).and_return('email')
            apps_handler.add_process(app_model, process, access_context)

            allow(process_handler).to receive(:update) do
              process.name = new_name
              process.save
            end
          end

          it 'also updates the name of the web process' do
            result = apps_handler.update(update_message, access_context)
            expect(result.guid).to eq(guid)
            expect(result.name).to eq(new_name)

            updated_app     = AppModel.find(guid: guid)
            updated_process = App.find(guid: process_guid)

            expect(updated_app.name).to eq(new_name)
            expect(updated_process.name).to eq(new_name)
          end

          it 'does not update the app or process if the process raises an exception' do
            allow(access_context).to receive(:cannot?).and_return(true).once
            expect {
              apps_handler.update(empty_update_message, access_context)
            }.to raise_error

            updated_app     = AppModel.find(guid: guid)
            updated_process = App.find(guid: process_guid)

            expect(updated_app.name).to eq(app_model.name)
            expect(updated_process.name).to eq(process.name)
          end
        end
      end

      context 'when the app does not exist' do
        let(:guid) { 'bad-guid' }

        it 'returns nil' do
          result = apps_handler.update(update_message, access_context)
          expect(result).to be_nil
        end
      end

      context 'when the app is invalid' do
        before do
          allow_any_instance_of(AppModel).to receive(:save).and_raise(Sequel::ValidationFailed.new('the message'))
        end

        it 'raises an AppInvalid error' do
          expect {
            apps_handler.update(update_message, access_context)
          }.to raise_error(AppsHandler::InvalidApp, 'the message')
        end
      end
    end

    describe '#delete' do
      context 'when the app does not exist' do
        let(:guid) { 'ABC123' }

        it 'returns nil' do
          result = apps_handler.delete(guid, access_context)
          expect(result).to be_nil
        end
      end

      context 'when the app does exist' do
        let(:app_model) { AppModel.make }
        let(:guid) { app_model.guid }

        context 'when the user cannot access the app' do
          before do
            allow(access_context).to receive(:cannot?).and_return(true)
          end

          it 'raises Unauthorized' do
            expect {
              apps_handler.delete(guid, access_context)
            }.to raise_error(AppsHandler::Unauthorized)
            expect(access_context).to have_received(:cannot?).with(:delete, app_model)
          end
        end

        context 'when the user has access to the app' do
          it 'deletes the app' do
            result = apps_handler.delete(guid, access_context)
            expect(result).not_to be_nil

            deleted_app = AppModel.find(guid: guid)
            expect(deleted_app).to be_nil
          end
        end

        context 'when the app has child processes' do
          before do
            AppFactory.make(app_guid: guid)
          end

          it 'raises a OliverTwist error' do
            expect {
              apps_handler.delete(guid, access_context)
            }.to raise_error(AppsHandler::DeleteWithProcesses)
          end
        end
      end
    end

    describe '#add_process' do
      let(:app_model) { AppModel.make }
      let(:guid) { app_model.guid }
      let(:process) { AppFactory.make(type: 'special', space_guid: app_model.space_guid) }

      context 'when the user cannot update the app' do
        before do
          allow(access_context).to receive(:cannot?).and_return(true)
        end

        it 'raises Unauthorized' do
          expect {
            apps_handler.add_process(app_model, process, access_context)
          }.to raise_error(AppsHandler::Unauthorized)
          expect(access_context).to have_received(:cannot?).with(:update, app_model)
        end
      end

      context 'when the app already has a process with the same type' do
        before do
          existing_process = AppFactory.make(type: process.type)
          app_model.add_process_by_guid(existing_process.guid)
        end

        it 'raises DuplicateProcessType error' do
          expect {
            apps_handler.add_process(app_model, process, access_context)
          }.to raise_error(AppsHandler::DuplicateProcessType)
        end
      end

      context 'when the process is not in the same space as the app' do
        let(:another_space) { Space.make }
        let(:process) { AppFactory.make(type: 'special', space_guid: another_space.guid) }

        it 'raises IncorrectProcessSpace error' do
          expect {
            apps_handler.add_process(app_model, process, access_context)
          }.to raise_error(AppsHandler::IncorrectProcessSpace)
        end
      end

      context 'when the process is already associated with the app' do
        before do
          apps_handler.add_process(app_model, process, access_context)
        end

        it 'does nothing' do
          expect(app_model.processes.count).to eq(1)
          apps_handler.add_process(app_model, process, access_context)

          app_model.reload
          expect(app_model.processes.count).to eq(1)
        end
      end

      context 'when a user can add a process to the app' do
        it 'adds the process' do
          expect(app_model.processes.count).to eq(0)

          apps_handler.add_process(app_model, process, access_context)

          app_model.reload
          expect(app_model.processes.count).to eq(1)
          expect(app_model.processes.first.guid).to eq(process.guid)
        end
      end
    end

    describe '#remove_process' do
      let(:app_model) { AppModel.make }
      let(:guid) { app_model.guid }
      let(:process) { AppFactory.make }

      before do
        app_model.add_process(process)
        process.reload
      end

      context 'when the user cannot update the app' do
        before do
          allow(access_context).to receive(:cannot?).and_return(true)
        end

        it 'raises Unauthorized' do
          expect {
            apps_handler.remove_process(app_model, process, access_context)
          }.to raise_error(AppsHandler::Unauthorized)
          expect(access_context).to have_received(:cannot?).with(:update, app_model)
        end
      end

      context 'when the process does not belong to the app' do
        let(:process) { AppFactory.make }

        it 'does not break' do
          expect {
            apps_handler.remove_process(app_model, process, access_context)
          }.not_to raise_error
        end
      end

      context 'when user can remove the app' do
        it 'removes the app' do
          expect(app_model.processes.count).to eq(1)

          apps_handler.remove_process(app_model, process, access_context)

          expect(app_model.processes.count).to eq(0)
        end
      end
    end
  end
end
