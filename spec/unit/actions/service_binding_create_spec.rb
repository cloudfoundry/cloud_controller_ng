require 'spec_helper'
require 'actions/service_binding_create'

module VCAP::CloudController
  RSpec.describe ServiceBindingCreate do
    RSpec::Matchers.define_negated_matcher :not_change, :change

    describe '#create' do
      subject(:service_binding_create) { ServiceBindingCreate.new(user_audit_info) }
      let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }
      let(:volume_mount_services_enabled) { true }

      let(:app) { AppModel.make }
      let(:service_instance) { ManagedServiceInstance.make(space: app.space) }
      let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, unbind: {}) }
      let(:accepts_incomplete) { false }
      let(:request) do
        {
          'type'          => 'app',
          'name'          => 'named-binding',
          'relationships' => {
            'app' => {
              'guid' => app.guid
            },
            'service_instance' => {
              'guid' => service_instance.guid
            },
            'data' => { 'parameters' => arbitrary_parameters }
          },
        }
      end
      let(:message) { ServiceBindingCreateMessage.new(request) }
      let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }
      let(:logger) { instance_double(Steno::Logger) }
      let(:arbitrary_parameters) { {} }

      before do
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        allow(client).to receive(:bind).and_return({ async: false, binding: {} })
      end

      it 'creates a Service Binding' do
        service_binding = service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)

        expect(ServiceBinding.count).to eq(1)
        expect(service_binding.app_guid).to eq(app.guid)
        expect(service_binding.service_instance_guid).to eq(service_instance.guid)
        expect(service_binding.type).to eq('app')
        expect(service_binding.name).to eq('named-binding')
      end

      it 'creates an audit.service_binding.create event' do
        service_binding = service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)

        event = Event.last
        expect(event.type).to eq('audit.service_binding.create')
        expect(event.actee).to eq(service_binding.guid)
        expect(event.actee_type).to eq('service_binding')
      end

      context 'when the instance has another operation in progress' do
        it 'fails' do
          ServiceInstanceOperation.make(service_instance_id: service_instance.id, state: 'in progress')

          expect {
            service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
          }.to raise_error do |e|
            expect(e).to be_a(CloudController::Errors::ApiError)
            expect(e.message).to include('in progress')
          end
        end
      end

      context 'when the service is not bindable' do
        before do
          service_instance.service.bindable = false
          service_instance.service.save
        end

        it 'raises ServiceInstanceNotBindable' do
          expect {
            service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
          }.to raise_error(ServiceBindingCreate::ServiceInstanceNotBindable)
        end
      end

      context 'when the service binding is invalid' do
        before do
          allow_any_instance_of(ServiceBinding).to receive(:valid?).and_return(false)
        end

        it 'raises InvalidServiceBinding' do
          expect {
            service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
          }.to raise_error(ServiceBindingCreate::InvalidServiceBinding)
        end
      end

      context 'when volume mount services are disabled and the service requires volume_mount' do
        let(:volume_mount_services_enabled) { false }
        let(:service_instance) { ManagedServiceInstance.make(:volume_mount, space_guid: app.space.guid) }

        it 'raises a VolumeMountServiceDisabled error' do
          expect {
            service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
          }.to raise_error ServiceBindingCreate::VolumeMountServiceDisabled
        end
      end

      context 'when the app and service instance are in different spaces' do
        let(:app) { AppModel.make(space: Space.make) }
        let(:service_instance) { ManagedServiceInstance.make(space: Space.make) }

        context 'when the service instance has not been shared into the app space' do
          it 'raises a SpaceMismatch error' do
            expect {
              service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
            }.to raise_error ServiceBindingCreate::SpaceMismatch
          end
        end

        context 'when the service instance has been shared into the app space' do
          before do
            service_instance.add_shared_space(app.space)
          end

          it 'creates the service binding' do
            expect {
              service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
            }.to change { ServiceBinding.count }.by 1
          end
        end
      end

      context 'when accepts_incomplete is set to true' do
        let(:accepts_incomplete) { true }

        it 'passes the accepts_incomplete parameter to the broker client' do
          expect(client).to receive(:bind).with(instance_of(VCAP::CloudController::ServiceBinding), anything, true)
          service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
        end

        context 'and the broker responds asynchronously' do
          before do
            allow(client).to receive(:bind).and_return({ async: true, binding: {}, operation: '123' })
            allow(client).to receive(:fetch_service_binding_last_operation).with(instance_of(VCAP::CloudController::ServiceBinding)).
              and_return({ last_operation: { state: 'in progress', description: '10% complete' } })
          end

          it 'returns the binding operation' do
            service_binding = service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
            expect(ServiceBinding.count).to eq(1)
            expect(ServiceBindingOperation.count).to eq(1)
            expect(service_binding.last_operation.state).to eq('in progress')
          end

          it 'service binding operation has broker provided operation' do
            service_binding = service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
            expect(service_binding.last_operation.broker_provided_operation).to eq('123')
          end

          it 'service binding operation has type create' do
            service_binding = service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
            expect(service_binding.last_operation.type).to eq('create')
          end

          it 'expect to fetch last operation' do
            service_binding = service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
            expect(service_binding.last_operation.state).to eq('in progress')
            expect(service_binding.last_operation.description).to eq('10% complete')
          end

          context 'when the create ServiceBindingOperation fails' do
            before do
              allow(ServiceBindingOperation).to receive(:create).and_raise('failed')
            end

            it 'should NOT insert binding when the operation fails to create' do
              expect {
                service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
              }.to raise_error('failed').and not_change(ServiceBinding, :count)
            end

            it 'should trigger orphan mitigation' do
              expect_any_instance_of(SynchronousOrphanMitigate).to receive(:attempt_unbind)

              expect {
                service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
              }.to raise_error('failed')

              expect(client).to have_received(:bind)
            end
          end
        end
      end

      context 'when accepts_incomplete is set to false' do
        let(:accepts_incomplete) { false }

        it 'passes the accepts_incomplete parameter to the broker client' do
          expect(client).to receive(:bind).with(instance_of(VCAP::CloudController::ServiceBinding), anything, false)
          service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
        end
      end

      describe 'orphan mitigation situations' do
        context 'when the broker returns an error on creation' do
          before do
            allow(client).to receive(:bind).and_raise('meow')
          end

          it 'does not create a binding' do
            expect {
              service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
            }.to raise_error 'meow'

            expect(ServiceBinding.count).to eq 0
          end
        end

        context 'when broker request is successful but the database fails to save the binding (Hail Mary)' do
          before do
            stub_bind(service_instance)
            stub_request(:delete, service_binding_url_pattern)

            allow(service_binding_create).to receive(:logger).and_return(logger)
            allow_any_instance_of(ServiceBinding).to receive(:save).and_raise('meow')
            allow(logger).to receive(:error)
            allow(logger).to receive(:info)
          end

          it 'immediately attempts to unbind the service instance' do
            expect_any_instance_of(SynchronousOrphanMitigate).to receive(:attempt_unbind)

            expect {
              service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
            }.to raise_error('meow')

            expect(client).to have_received(:bind)
          end

          it 'does not try to enqueue a delayed job for orphan mitigation' do
            expect {
              service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
            }.to raise_error('meow')

            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).to be_nil
          end

          it 'logs that the unbind failed' do
            expect {
              service_binding_create.create(app, service_instance, message, volume_mount_services_enabled, accepts_incomplete)
            }.to raise_error('meow')

            expect(logger).to have_received(:error).with /Failed to save/
          end
        end
      end
    end
  end
end
