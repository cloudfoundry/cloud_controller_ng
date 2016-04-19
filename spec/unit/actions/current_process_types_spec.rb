require 'spec_helper'
require 'actions/current_process_types'

module VCAP::CloudController
  describe CurrentProcessTypes do
    let(:user) { double(:user, guid: Sham.guid) }
    let(:droplet) { nil }
    let(:app) { AppModel.make(droplet: droplet, name: 'my_app') }
    subject(:current_process_types) { CurrentProcessTypes.new(user.guid, Sham.email) }

    describe '#process_current_droplet' do
      let(:process_types) { { web: 'thing', other: 'stuff' } }
      let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: process_types) }

      describe 'adding processes' do
        it 'adds missing processes' do
          expect(app.processes.count).to eq(0)
          current_process_types.process_current_droplet(app)

          app.reload
          expect(app.processes.count).to eq(2)
        end

        it 'adds the route to the process' do
          route = Route.make(space: app.space)
          RouteMappingModel.make(route: route, app: app, process_type: 'web')

          current_process_types.process_current_droplet(app)

          process = App.where(app_guid: app.guid, type: 'web').first
          expect(process.routes).to include(route)
        end

        it 'records an "audit.app.process.create" event' do
          current_process_types.process_current_droplet(app)

          app.reload

          web_process   = App.where(app_guid: app.guid, type: 'web').first
          other_process = App.where(app_guid: app.guid, type: 'other').first

          web_event   = Event.all.find { |e| e.metadata['process_guid'] == web_process.guid }
          other_event = Event.all.find { |e| e.metadata['process_guid'] == other_process.guid }

          expect(web_event.type).to eq('audit.app.process.create')
          expect(other_event.type).to eq('audit.app.process.create')
        end

        describe 'default values for web processes' do
          let(:process_types) { { web: 'thing' } }

          it '1 instance, port health_check_type, nil ports' do
            current_process_types.process_current_droplet(app)
            app.reload

            expect(app.processes[0].instances).to eq(1)
            expect(app.processes[0].health_check_type).to eq('port')
            expect(app.processes[0].ports).to eq(nil)
          end
        end

        describe 'default values for non-web processes' do
          let(:process_types) { { other: 'stuff' } }

          it '0 instances, process health_check_type, nil ports' do
            current_process_types.process_current_droplet(app)
            app.reload

            expect(app.processes[0].instances).to eq(0)
            expect(app.processes[0].health_check_type).to eq('process')
            expect(app.processes[0].ports).to eq(nil)
          end
        end
      end

      it 'deletes processes that are no longer mentioned' do
        process_to_delete = App.make(type: 'bogus', space: app.space, app: app)

        current_process_types.process_current_droplet(app)

        expect(process_to_delete.exists?).to be_falsey
      end

      it 'updates existing processes' do
        existing_process = AppFactory.make(type: 'other', command: 'old', space: app.space, app: app)
        expect {
          current_process_types.process_current_droplet(app)
        }.to change { existing_process.refresh.command }.from('old').to('stuff')
      end

      context 'when the app does not have droplet' do
        let(:droplet) { nil }

        it 'raises a ProcessTypesNotFound error' do
          expect {
            current_process_types.process_current_droplet(app)
          }.to raise_error(CurrentProcessTypes::ProcessTypesNotFound)
        end
      end

      context 'when the app has a droplet, but the droplet does not have a process type' do
        let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: nil) }
        let(:app) { AppModel.make(droplet: droplet) }

        it 'raises procfile not found' do
          expect {
            current_process_types.process_current_droplet(app)
          }.to raise_error(CurrentProcessTypes::ProcessTypesNotFound)
        end
      end
    end
  end
end
