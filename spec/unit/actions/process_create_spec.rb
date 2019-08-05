require 'spec_helper'
require 'actions/process_create'

module VCAP::CloudController
  RSpec.describe ProcessCreate do
    subject(:process_create) { ProcessCreate.new(user_audit_info) }
    let(:app) { AppModel.make }
    let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }

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
        expect(process.instances).to eq(1)
      end

      context 'if the command is nil' do
        let(:message) do
          {
            type:    'web',
            command: nil
          }
        end

        it 'creates the process with no command' do
          process = process_create.create(app, message)

          app.reload
          expect(app.processes.count).to eq(1)
          expect(app.processes.first.guid).to eq(process.guid)
          expect(process.type).to eq('web')
          expect(process.command).to eq(nil)
        end
      end

      it 'adds existing routes to the process' do
        route = Route.make(space: app.space)
        destination = RouteMappingModel.make(
          route: route,
          app: app,
          process_type: 'web',
          app_port: 3121
        )

        process = process_create.create(app, message)

        expect(process.routes).to include(route)
        expect(process.ports).to include(destination.app_port)
      end

      it 'validates number of ports when adding existing routes to a new process' do
        route = Route.make(space: app.space)
        11.times do |i|
          RouteMappingModel.make(
            route: route,
            app: app,
            process_type: 'web',
            app_port: 3120 + i
          )
        end

        expect {
          process_create.create(app, message)
        }.to raise_error ProcessCreate::InvalidProcess, 'Process must have at most 10 exposed ports.'
      end

      it 'validates sidecar memory usage' do
        sidecar = SidecarModel.make(app: app, name: 'my_sidecar', command: 'athenz', memory: 2000)
        SidecarProcessTypeModel.make(sidecar: sidecar, type: message[:type])

        expect {
          process_create.create(app, message)
        }.to raise_error(
          ProcessCreate::SidecarMemoryLessThanProcessMemory,
          /The sidecar memory allocation defined is too large to run with the dependent "web" process/
        )
      end

      describe 'audit events' do
        it 'records an "audit.app.process.create" event' do
          process = process_create.create(app, message)

          event = Event.last
          expect(event.type).to eq('audit.app.process.create')
          expect(event.metadata['process_guid']).to eq(process.guid)
          expect(event.metadata['manifest_triggered']).to eq(nil)
        end

        context 'when the create is manifest triggered' do
          subject(:process_create) { ProcessCreate.new(user_audit_info, manifest_triggered: true) }

          it 'tags the event as manifest triggered' do
            process_create.create(app, message)

            event = Event.last
            expect(event.type).to eq('audit.app.process.create')
            expect(event.metadata['manifest_triggered']).to eq(true)
          end
        end
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

        it 'sets process guid to the app guid' do
          process = process_create.create(app, message)
          expect(process.guid).to eq(app.guid)
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
