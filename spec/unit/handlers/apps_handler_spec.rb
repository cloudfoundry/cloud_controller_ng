require 'spec_helper'
require 'handlers/apps_handler'
module VCAP::CloudController
  describe AppsHandler do
    let(:packages_handler) { double(:packages_handler) }
    let(:droplets_handler) { double(:droplets_handler) }
    let(:processes_handler) { double(:processes_handler) }
    let(:apps_handler) { described_class.new(packages_handler, droplets_handler, processes_handler) }
    let(:access_context) { double(:access_context, user: User.make, user_email: 'jim@jim.com') }

    before do
      allow(access_context).to receive(:cannot?).and_return(false)
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

    describe '#add_process' do
      let(:app_model) { AppModel.make }
      let(:guid) { app_model.guid }
      let(:process) { AppFactory.make(type: 'web', space_guid: app_model.space_guid) }

      context 'when the app has routes for the same process type' do
        before do
          allow(access_context).to receive(:cannot?).and_return(false)
        end

        it 'associates that route to the process' do
          route1 = Route.make(space: app_model.space)
          route2 = Route.make(space: app_model.space)
          AddRouteToApp.new(app_model).add(route1)
          AddRouteToApp.new(app_model).add(route2)
          apps_handler.add_process(app_model, process, access_context)
          expect(process.reload.routes).to eq([route1, route2])
        end
      end

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

        it 'creates an audit event' do
          apps_handler.add_process(app_model, process, access_context)

          event = Event.last
          expect(event.type).to eq('audit.app.add_process')
          expect(event.actor).to eq(access_context.user.guid)
          expect(event.actor_name).to eq(access_context.user_email)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee).to eq(app_model.guid)
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

        it 'creates an audit event' do
          apps_handler.add_process(app_model, process, access_context)

          event = Event.last
          expect(event.type).to eq('audit.app.add_process')
          expect(event.actor).to eq(access_context.user.guid)
          expect(event.actor_name).to eq(access_context.user_email)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee).to eq(app_model.guid)
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

        it 'creates an audit event' do
          apps_handler.remove_process(app_model, process, access_context)

          event = Event.last
          expect(event.type).to eq('audit.app.remove_process')
          expect(event.actor).to eq(access_context.user.guid)
          expect(event.actor_name).to eq(access_context.user_email)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee).to eq(app_model.guid)
        end
      end

      context 'when user can remove the app' do
        it 'removes the app' do
          expect(app_model.processes.count).to eq(1)

          apps_handler.remove_process(app_model, process, access_context)

          expect(app_model.processes.count).to eq(0)
        end

        it 'creates an audit event' do
          apps_handler.remove_process(app_model, process, access_context)

          event = Event.last
          expect(event.type).to eq('audit.app.remove_process')
          expect(event.actor).to eq(access_context.user.guid)
          expect(event.actor_name).to eq(access_context.user_email)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee).to eq(app_model.guid)
        end
      end
    end
  end
end
