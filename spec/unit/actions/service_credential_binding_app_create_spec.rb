require 'spec_helper'
require 'actions/service_credential_binding_app_create'
require 'support/shared_examples/v3_service_binding_create'
require 'cloud_controller/user_audit_info'
require 'repositories/service_generic_binding_event_repository'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceCredentialBindingAppCreate do
      subject(:action) { described_class.new(user_audit_info, audit_hash) }

      let(:audit_hash) { { some_info: 'some_value' } }
      let(:volume_mount_services_enabled) { true }
      let(:space) { Space.make }
      let(:app) { AppModel.make(space: space) }
      let(:binding_details) {}
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'run@lola.run', user_guid: '100_000') }
      let(:binding_event_repo) { instance_double(Repositories::ServiceGenericBindingEventRepository) }

      before do
        allow(Repositories::ServiceGenericBindingEventRepository).to receive(:new).with('service_binding').and_return(binding_event_repo)
        allow(binding_event_repo).to receive(:record_create)
        allow(binding_event_repo).to receive(:record_start_create)
      end

      describe '#precursor' do
        RSpec.shared_examples 'the credential binding precursor' do
          it 'returns a service credential binding precursor' do
            binding = action.precursor(service_instance, app: app, name: details[:name])
            expect(binding).to be
            expect(binding).to eq(ServiceBinding.where(guid: binding.guid).first)
            expect(binding.service_instance).to eq(service_instance)
            expect(binding.app).to eq(app)
            expect(binding.name).to eq(details[:name])
            expect(binding.credentials).to be_empty
            expect(binding.syslog_drain_url).to be_nil
            expect(binding.last_operation.type).to eq('create')
            expect(binding.last_operation.state).to eq('in progress')
          end

          it 'raises an error when no app is specified' do
            expect { action.precursor(service_instance) }.to raise_error(
              ServiceCredentialBindingAppCreate::UnprocessableCreate,
              'No app was specified'
            )
          end

          it 'raises an error when a binding already exists' do
            ServiceBinding.make(service_instance: service_instance, app: app)
            expect { action.precursor(service_instance, app: app, name: details[:name]) }.to raise_error(
              ServiceCredentialBindingAppCreate::UnprocessableCreate,
              'The app is already bound to the service instance'
            )
          end

          it 'raises an error when a the app and the instance are in different spaces' do
            another_space = Space.make
            another_app = AppModel.make(space: another_space)
            expect { action.precursor(service_instance, app: another_app, name: details[:name]) }.to raise_error(
              ServiceCredentialBindingAppCreate::UnprocessableCreate,
              'The service instance and the app are in different spaces'
            )
          end
        end

        context 'user-provided service instance' do
          let(:details) { {
            space: space,
            name: 'tykwer',
            credentials: { 'password' => 'rennt', 'username' => 'lola' },
            syslog_drain_url: 'https://drain.syslog.example.com/runlolarun'
          }
          }
          let(:service_instance) { UserProvidedServiceInstance.make(**details) }

          it_behaves_like 'the credential binding precursor'
        end

        context 'managed service instance' do
          let(:details) do
            {
              space: space
            }
          end

          let(:service_instance) { ManagedServiceInstance.make(**details) }

          context 'validations' do
            context 'when plan is not bindable' do
              before do
                service_instance.service_plan.update(bindable: false)
              end

              it 'raises an error' do
                expect { action.precursor(service_instance, app: app) }.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'Service plan does not allow bindings'
                )
              end
            end

            context 'when plan is not available' do
              before do
                service_instance.service_plan.update(active: false)
              end

              it 'raises an error' do
                expect { action.precursor(service_instance, app: app) }.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'Service plan is not available'
                )
              end
            end

            context 'when the service is a volume service and service volume mounting is disabled' do
              let(:service_instance) { ManagedServiceInstance.make(:volume_mount, **details) }

              it 'raises an error' do
                expect {
                  action.precursor(service_instance, app: app, volume_mount_services_enabled: false)
                }.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'Support for volume mount services is disabled'
                )
              end
            end

            context 'when there is an operation in progress for the service instance' do
              it 'raises an error' do
                service_instance.save_with_new_operation({}, { type: 'tacos', state: 'in progress' })

                expect {
                  action.precursor(service_instance, app: app, volume_mount_services_enabled: false)
                }.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'There is an operation in progress for the service instance'
                )
              end
            end

            context 'when the service is a volume service and service volume mounting is enabled' do
              let(:service_instance) { ManagedServiceInstance.make(:volume_mount, **details) }

              it 'does not raise an error' do
                expect {
                  action.precursor(service_instance, app: app, volume_mount_services_enabled: true)
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

              it_behaves_like 'the credential binding precursor'
            end
          end
          context 'when successful' do
            it_behaves_like 'the credential binding precursor'
          end
        end
      end

      context '#bind' do
        let(:precursor) { action.precursor(service_instance, app: app) }
        let(:details) {
          {
            credentials: { 'password' => 'rennt', 'username' => 'lola' },
            syslog_drain_url: 'https://drain.syslog.example.com/runlolarun'
          }
        }
        let(:bind_response) { { binding: details } }

        it_behaves_like 'service binding creation', ServiceBinding

        describe 'app specific behaviour' do
          context 'managed service instance' do
            let(:service_offering) { Service.make(bindings_retrievable: true) }
            let(:service_plan) { ServicePlan.make(service: service_offering) }
            let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
            let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: bind_response) }

            before do
              allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
            end

            it_behaves_like 'the sync credential binding', ServiceBinding, true

            context 'asynchronous binding' do
              let(:broker_provided_operation) { Sham.guid }
              let(:bind_async_response) { { async: true, operation: broker_provided_operation } }
              let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: bind_async_response) }

              it 'should log audit start_create' do
                action.bind(precursor)
                expect(binding_event_repo).to have_received(:record_start_create).with(
                  precursor,
                  user_audit_info,
                  audit_hash,
                  manifest_triggered: false,
                )
              end
            end
          end

          context 'user-provided service instance' do
            let(:details) {
              {
                space: space,
                credentials: { 'password' => 'rennt', 'username' => 'lola' },
                syslog_drain_url: 'https://drain.syslog.example.com/runlolarun'
              }
            }
            let(:service_instance) { UserProvidedServiceInstance.make(**details) }

            it_behaves_like 'the sync credential binding', ServiceBinding, true
          end
        end
      end

      describe '#poll' do
        let(:binding) { action.precursor(service_instance, app: app, name: 'original-name') }
        let(:credentials) { { 'password' => 'rennt', 'username' => 'lola' } }
        let(:volume_mounts) { [{
            'driver' => 'cephdriver',
            'container_dir' => '/data/images',
            'mode' => 'r',
            'device_type' => 'shared',
            'device' => {
              'volume_id' => 'bc2c1eab-05b9-482d-b0cf-750ee07de311',
              'mount_config' => {
                'key' => 'value'
              }
            }
          }]
        }
        let(:syslog_drain_url) { 'https://drain.syslog.example.com/runlolarun' }
        let(:fetch_binding_response) { { credentials: credentials, syslog_drain_url: syslog_drain_url, volume_mounts: volume_mounts, name: 'updated-name' } }

        it_behaves_like 'polling service binding creation'

        describe 'app specific behaviour' do
          let(:service_offering) { Service.make(bindings_retrievable: true, requires: ['route_forwarding']) }
          let(:service_plan) { ServicePlan.make(service: service_offering) }
          let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
          let(:broker_provided_operation) { Sham.guid }
          let(:bind_response) { { async: true, operation: broker_provided_operation } }
          let(:description) { Sham.description }
          let(:state) { 'in progress' }
          let(:fetch_last_operation_response) do
            {
              last_operation: {
                state: state,
                description: description,
              },
            }
          end
          let(:broker_client) do
            instance_double(
              VCAP::Services::ServiceBrokers::V2::Client,
              {
                bind: bind_response,
                fetch_and_handle_service_binding_last_operation: fetch_last_operation_response,
                fetch_service_binding: fetch_binding_response,
              }
            )
          end

          before do
            allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)

            action.bind(binding, accepts_incomplete: true)
          end

          context 'response says complete' do
            let(:description) { Sham.description }
            let(:state) { 'succeeded' }

            it 'fetches the service binding and updates only the credentials, volume_mounts and syslog_drain_url' do
              action.poll(binding)

              expect(broker_client).to have_received(:fetch_service_binding).with(binding)

              binding.reload
              expect(binding.credentials).to eq(credentials)
              expect(binding.syslog_drain_url).to eq(syslog_drain_url)
              expect(binding.volume_mounts).to eq(volume_mounts)
              expect(binding.name).to eq('original-name')
            end

            it 'creates an audit event' do
              action.poll(binding)

              expect(binding_event_repo).to have_received(:record_create).with(
                binding,
                user_audit_info,
                audit_hash,
                manifest_triggered: false,
              )
            end
          end

          context 'response says in progress' do
            it 'does not create an audit event' do
              action.poll(binding)

              expect(binding_event_repo).not_to have_received(:record_create)
            end
          end

          context 'response says failed' do
            let(:state) { 'failed' }
            it 'does not create an audit event' do
              expect { action.poll(binding) }.to raise_error(VCAP::CloudController::V3::LastOperationFailedState)

              expect(binding_event_repo).not_to have_received(:record_create)
            end
          end
        end
      end
    end
  end
end
