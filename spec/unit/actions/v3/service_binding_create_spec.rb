require 'db_spec_helper'
require 'actions/v3/service_binding_create'
require 'cloud_controller/user_audit_info'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceBindingCreate do
      subject(:action) { described_class.new(user_audit_info: user_audit_info, audit_hash: audit_hash) }

      let(:audit_hash) { { some_info: 'some_value' } }
      let(:volume_mount_services_enabled) { true }
      let(:space) { Space.make }
      let(:app) { AppModel.make(space: space) }
      let(:binding_details) {}
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'run@lola.run', user_guid: '100_000') }

      before do
        @service_binding_event_repository = Repositories::ServiceBindingEventRepository
        allow(@service_binding_event_repository).to receive(:record_create)
      end

      describe '#bind' do
        describe 'credential bindings' do
          let(:details) {
            { space: space, name: 'some-binding-name' }
          }
          let(:service_instance) { ManagedServiceInstance.make(**details) }

          context 'managed service instance' do
            context 'when no binding exists' do
              it 'returns the binding guid and that it needs a job' do
                binding_guid, needs_job = action.bind(service_instance, app: app, name: details[:name])
                expect(needs_job).to eq(true)
                expect(binding_guid).to be
                expect(binding_guid).to eq(ServiceBinding.last.guid)
              end

              it 'creates an incomplete binding in the db' do
                binding_guid, _ = action.bind(service_instance, app: app, name: details[:name])
                binding = ServiceBinding.first(guid: binding_guid)
                expect(binding.service_instance).to eq(service_instance)
                expect(binding.app).to eq(app)
                expect(binding.name).to eq(details[:name])
                expect(binding.credentials).to be_empty
                expect(binding.syslog_drain_url).to be_nil
                expect(binding.last_operation.type).to eq('create')
                expect(binding.last_operation.state).to eq('in progress')
              end

              context 'when plan is not bindable' do
                before do
                  service_instance.service_plan.update(bindable: false)
                end

                it 'raises an error' do
                  expect { action.bind(service_instance, app: app) }.to raise_error(
                    ServiceBindingCreate::UnprocessableCreate,
                    'Service plan does not allow bindings'
                  )
                end
              end

              context 'when plan is not available' do
                before do
                  service_instance.service_plan.update(active: false)
                end

                it 'raises an error' do
                  expect { action.bind(service_instance, app: app) }.to raise_error(
                    ServiceBindingCreate::UnprocessableCreate,
                    'Service plan is not available'
                  )
                end
              end

              context 'when the service is a volume service and service volume mounting is disabled' do
                let(:service_instance) { ManagedServiceInstance.make(:volume_mount, **details) }

                it 'raises an error' do
                  expect {
                    action.bind(service_instance, app: app, volume_mount_services_enabled: false)
                  }.to raise_error(
                    ServiceBindingCreate::UnprocessableCreate,
                    'Support for volume mount services is disabled'
                  )
                end
              end

              context 'when there is an operation in progress for the service instance' do
                it 'raises an error' do
                  service_instance.save_with_new_operation({}, { type: 'tacos', state: 'in progress' })

                  expect {
                    action.bind(service_instance, app: app, volume_mount_services_enabled: false)
                  }.to raise_error(
                    ServiceBindingCreate::UnprocessableCreate,
                    'There is an operation in progress for the service instance'
                  )
                end
              end

              context 'when the service is a volume service and service volume mounting is enabled' do
                let(:service_instance) { ManagedServiceInstance.make(:volume_mount, **details) }

                it 'does not raise an error' do
                  expect {
                    action.bind(service_instance, app: app, volume_mount_services_enabled: true)
                  }.not_to raise_error
                end
              end

              context 'when binding from an app in a shared space' do
                let(:other_space) { Space.make }
                let(:service_instance) do
                  ManagedServiceInstance.make(space: other_space).tap do |si|
                    si.add_shared_space(space)
                  end
                end

                it 'returns the binding guid and that it needs a job' do
                  binding_guid, needs_job = action.bind(service_instance, app: app, name: details[:name])
                  expect(needs_job).to eq(true)
                  expect(binding_guid).to be
                  expect(binding_guid).to eq(ServiceBinding.last.guid)
                end
              end
            end

            context 'when a binding guid is passed in' do
              let(:details) { { credentials: { 'password' => 'orchestra' } } }
              let(:service_instance) { ManagedServiceInstance.make(space: space) }
              let(:bind_response) { { binding: { credentials: details[:credentials] } } }
              let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: bind_response) }
              let(:binding_guid) { ServiceBinding.make(service_instance: service_instance, app: app).guid }
              subject(:action) { described_class.new(user_audit_info: user_audit_info, audit_hash: audit_hash, binding_guid: binding_guid) }

              before do
                allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
              end

              context 'parameters are specified' do
                it 'sends the parameters to the broker client' do
                  action.bind(service_instance, parameters: { foo: 'bar' })

                  expect(broker_client).to have_received(:bind).with(
                    ServiceBinding.last,
                    arbitrary_parameters: { foo: 'bar' },
                    accepts_incomplete: false,
                  )
                end
              end

              context 'synchronous binding' do
                it 'completes the operation' do
                  binding_guid, needs_job = action.bind(service_instance)
                  binding = ServiceBinding.first(guid: binding_guid)

                  expect(needs_job).to eq(false)
                  expect(binding).to eq(ServiceBinding.first)
                  expect(binding.credentials).to eq(details[:credentials])
                  expect(binding.syslog_drain_url).to eq(details[:syslog_drain_url])
                  expect(binding.last_operation.type).to eq('create')
                  expect(binding.last_operation.state).to eq('succeeded')
                end

                it 'creates an audit event' do
                  action.bind(service_instance)

                  expect(@service_binding_event_repository).to have_received(:record_create).with(
                    ServiceBinding.last,
                    user_audit_info,
                    audit_hash,
                    manifest_triggered: false,
                  )
                end
              end

              context 'asynchronous binding' do
                let(:broker_provided_operation) { Sham.guid }
                let(:bind_response) { { async: true, operation: broker_provided_operation } }

                it 'saves the operation ID' do
                  binding_guid, need_job = action.bind(service_instance, accepts_incomplete: true)

                  expect(broker_client).to have_received(:bind).with(
                    ServiceBinding.last,
                    arbitrary_parameters: {},
                    accepts_incomplete: true,
                  )

                  expect(need_job).to eq(true)
                  binding = ServiceBinding.first(guid: binding_guid)
                  expect(binding.last_operation.type).to eq('create')
                  expect(binding.last_operation.state).to eq('in progress')
                  expect(binding.last_operation.broker_provided_operation).to eq(broker_provided_operation)
                end
              end

              it 'fails the create if cannot complete' do
                allow_any_instance_of(ServiceBinding).to receive(:save_with_new_operation).
                  with({ type: 'create', state: 'succeeded' }, attributes: anything).
                  and_raise(Sequel::ValidationFailed, 'Meh')
                allow_any_instance_of(ServiceBinding).to receive(:save_with_new_operation).
                  with({ type: 'create', state: 'failed', description: 'Meh' }).
                  and_call_original

                expect { action.bind(service_instance) }.to raise_error(Sequel::ValidationFailed, 'Meh')

                binding = ServiceBinding.last
                expect(binding.last_operation.type).to eq('create')
                expect(binding.last_operation.state).to eq('failed')
                expect(binding.last_operation.description).to eq('Meh')
              end
            end
          end

          context 'user provided service instance' do
            let(:details) {
              {
                space: space,
                name: 'tykwer',
                credentials: { 'password' => 'rennt', 'username' => 'lola' },
                syslog_drain_url: 'https://drain.syslog.example.com/runlolarun'
              }
            }
            let(:service_instance) { UserProvidedServiceInstance.make(**details) }

            it 'returns the binding guid and that it does not need a job' do
              binding_guid, needs_job = action.bind(service_instance, app: app, name: details[:name])
              expect(needs_job).to eq(false)
              expect(binding_guid).to be
              expect(binding_guid).to eq(ServiceBinding.last.guid)
            end

            it 'creates a complete binding in the db' do
              binding_guid, _ = action.bind(service_instance, app: app, name: details[:name])
              binding = ServiceBinding.first(guid: binding_guid)

              expect(binding.service_instance).to eq(service_instance)
              expect(binding.app).to eq(app)
              expect(binding.name).to eq(details[:name])
              expect(binding.credentials).to eq(details[:credentials])
              expect(binding.syslog_drain_url).to eq(details[:syslog_drain_url])
              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.state).to eq('succeeded')
            end

            it 'creates an audit event' do
              binding, _ = action.bind(service_instance, app: app, name: details[:name])
              expect(@service_binding_event_repository).to have_received(:record_create).with(
                ServiceBinding.first(guid: binding),
                user_audit_info,
                audit_hash,
                manifest_triggered: false,
              )
            end
          end

          it 'raises an error when no app is specified' do
            expect { action.bind(service_instance) }.to raise_error(
              ServiceBindingCreate::UnprocessableCreate,
              'No app was specified'
            )
          end

          it 'raises an error when a binding already exists' do
            ServiceBinding.make(service_instance: service_instance, app: app)
            expect { action.bind(service_instance, app: app) }.to raise_error(
              ServiceBindingCreate::UnprocessableCreate,
              'The app is already bound to the service instance'
            )
          end

          it 'raises an error when a the app and the instance are in different spaces' do
            another_space = Space.make
            another_app = AppModel.make(space: another_space)
            expect { action.bind(service_instance, app: another_app) }.to raise_error(
              ServiceBindingCreate::UnprocessableCreate,
              'The service instance and the app are in different spaces'
            )
          end
        end
      end
    end
  end
end

# RSpec.shared_examples 'the credential binding bind' do
#   it 'creates and returns the credential binding' do
#     action.bind(precursor)
#
#     precursor.reload
#     expect(precursor).to eq(ServiceBinding.first)
#     expect(precursor.credentials).to eq(details[:credentials])
#     expect(precursor.syslog_drain_url).to eq(details[:syslog_drain_url])
#     expect(precursor.last_operation.type).to eq('create')
#     expect(precursor.last_operation.state).to eq('succeeded')
#   end
#
#   it 'creates an audit event' do
#     action.bind(precursor)
#     expect(@service_binding_event_repository).to have_received(:record_create).with(
#       precursor,
#       user_audit_info,
#       audit_hash,
#       manifest_triggered: false,
#     )
#   end
#
#   TODO: think about this test
#   context 'when saving to the db fails' do
#     it 'fails the binding operation' do
#       allow(precursor).to receive(:save_with_new_operation).with({ type: 'create', state: 'succeeded' }, attributes: anything).and_raise(Sequel::ValidationFailed, 'Meh')
#       allow(precursor).to receive(:save_with_new_operation).with({ type: 'create', state: 'failed', description: 'Meh' }).and_call_original
#       expect { action.bind(precursor) }.to raise_error(Sequel::ValidationFailed, 'Meh')
#       precursor.reload
#       expect(precursor.last_operation.type).to eq('create')
#       expect(precursor.last_operation.state).to eq('failed')
#       expect(precursor.last_operation.description).to eq('Meh')
#     end
#   end
# end
