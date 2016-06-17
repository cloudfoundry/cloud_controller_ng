require 'spec_helper'
require 'actions/process_create'

module VCAP::CloudController
  RSpec.describe ProcessCreate do
    subject(:process_create) { described_class.new(user_guid, user_email) }
    let(:app) { AppModel.make }
    let(:user_guid) { 'user-guid' }
    let(:user_email) { 'user@example.com' }

    describe '#create' do
      let(:message) do
        {
          type:    'web',
          command: 'rackup'
        }
      end

      it 'creates the process' do
        process = process_create.create(app, message)

        app.reload
        expect(app.processes.count).to eq(1)
        expect(app.processes.first.guid).to eq(process.guid)
        expect(process.type).to eq('web')
        expect(process.command).to eq('rackup')
      end

      it 'adds existing routes to the process' do
        route = Route.make(space: app.space)
        RouteMappingModel.make(route: route, app: app, process_type: 'web')

        process = process_create.create(app, message)

        expect(process.routes).to include(route)
      end

      it 'records an "audit.app.process.create" event' do
        process = process_create.create(app, message)

        event = Event.last
        expect(event.type).to eq('audit.app.process.create')
        expect(event.metadata['process_guid']).to eq(process.guid)
      end

      describe 'default values for web processes' do
        let(:message) do
          {
            type:    'web',
            command: 'rackup'
          }
        end

        it '1 instance, port health_check_type, nil ports' do
          process = process_create.create(app, message)

          expect(process.instances).to eq(1)
          expect(process.health_check_type).to eq('port')
          expect(process.ports).to eq(nil)
          expect(process.diego).to be_truthy
        end
      end

      describe 'default values for non-web processes' do
        let(:message) do
          {
            type:    'other',
            command: 'gogogadget'
          }
        end
        it '0 instances, process health_check_type, nil ports' do
          process = process_create.create(app, message)

          expect(process.instances).to eq(0)
          expect(process.health_check_type).to eq('process')
          expect(process.ports).to eq(nil)
          expect(process.diego).to be_truthy
        end
      end
    end
  end
end
