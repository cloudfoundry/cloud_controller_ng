require 'spec_helper'
require 'actions/service_credential_binding_app_create'
require 'support/shared_examples/v3_service_binding_create'
require 'cloud_controller/user_audit_info'
require 'repositories/service_generic_binding_event_repository'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceCredentialBindingAppCreate do
      subject(:action) { described_class.new(user_audit_info, audit_hash, manifest_triggered:) }

      let(:manifest_triggered) { false }
      let(:audit_hash) { { some_info: 'some_value' } }
      let(:volume_mount_services_enabled) { true }
      let(:space) { Space.make }
      let(:app) { AppModel.make(space:) }
      let(:binding_details) {}
      let(:user_guid) { Sham.uaa_id }
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'run@lola.run', user_guid: user_guid) }
      let(:binding_event_repo) { instance_double(Repositories::ServiceGenericBindingEventRepository) }
      let(:name) { 'foo' }
      let(:message) do
        VCAP::CloudController::ServiceCredentialAppBindingCreateMessage.new(
          {
            name: name,
            metadata: {
              labels: {
                release: 'stable'
              },
              annotations: {
                'seriouseats.com/potato': 'fried'
              }
            }
          }
        )
      end

      before do
        allow(Repositories::ServiceGenericBindingEventRepository).to receive(:new).with('service_binding').and_return(binding_event_repo)
        allow(binding_event_repo).to receive(:record_create)
        allow(binding_event_repo).to receive(:record_start_create)
      end

      describe '#precursor' do
        RSpec.shared_examples 'the credential binding precursor' do
          it 'returns a service credential binding precursor' do
            binding = action.precursor(service_instance, app:, message:)

            expect(binding).not_to be_nil
            expect(binding).to eq(ServiceBinding.where(guid: binding.guid).first)
            expect(binding.service_instance).to eq(service_instance)
            expect(binding.app).to eq(app)
            expect(binding.name).to eq(name)
            expect(binding.credentials).to be_empty
            expect(binding.syslog_drain_url).to be_nil
            expect(binding.last_operation.type).to eq('create')
            expect(binding.last_operation.state).to eq('initial')
            expect(binding).to have_labels({ prefix: nil, key_name: 'release', value: 'stable' })
            expect(binding).to have_annotations({ prefix: 'seriouseats.com', key_name: 'potato', value: 'fried' })
          end

          it 'raises an error when no app is specified' do
            expect { action.precursor(service_instance, message:) }.to raise_error(
              ServiceCredentialBindingAppCreate::UnprocessableCreate,
              'No app was specified'
            )
          end

          context 'when a binding already exists' do
            let!(:binding) { ServiceBinding.make(service_instance:, app:) }

            context 'when no last binding operation exists' do
              it 'raises an error' do
                expect { action.precursor(service_instance, app:, message:) }.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'The app is already bound to the service instance'
                )
              end
            end

            context "when the last binding operation is in 'create failed' state" do
              before do
                binding.save_with_attributes_and_new_operation({}, { type: 'create', state: 'failed' })
              end

              it 'deletes the existing binding and creates a new one' do
                b = action.precursor(service_instance, app:, message:)

                expect(b.guid).not_to eq(binding.guid)
                expect(b).to be_create_in_progress
                expect { binding.reload }.to raise_error Sequel::NoExistingObject
              end
            end

            context "when the last binding operation is in 'create in progress' state" do
              before do
                binding.save_with_attributes_and_new_operation({}, { type: 'create', state: 'in progress' })
              end

              it 'raises an error' do
                expect { action.precursor(service_instance, app:, message:) }.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'The app is already bound to the service instance'
                )
              end
            end

            context "when the last binding operation is in 'create succeeded' state" do
              before do
                binding.save_with_attributes_and_new_operation({}, { type: 'create', state: 'succeeded' })
              end

              it 'raises an error' do
                expect { action.precursor(service_instance, app:, message:) }.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'The app is already bound to the service instance'
                )
              end
            end

            context "when the last binding operation is in 'delete failed' state" do
              before do
                binding.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'failed' })
              end

              it 'raises an error' do
                expect { action.precursor(service_instance, app:, message:) }.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'The binding is getting deleted or its deletion failed'
                )
              end
            end

            context "when the last binding operation is in 'delete in progress' state" do
              before do
                binding.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'in progress' })
              end

              it 'raises an error' do
                expect { action.precursor(service_instance, app:, message:) }.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'The binding is getting deleted or its deletion failed'
                )
              end
            end
          end

          context 'when creating bindings with the same binding name concurrently' do
            let(:si_details) do
              {
                space:
              }
            end
            let(:service_instance2) { ManagedServiceInstance.make(**si_details) }

            it 'raises an error when the binding name already exists' do
              # First request, should succeed
              expect do
                action.precursor(service_instance, app:, message:)
              end.not_to raise_error

              # Mock the validation for the second request to simulate the race condition and trigger a
              # unique constraint violation on app_guid + name
              allow_any_instance_of(ServiceBinding).to receive(:validate).and_return(true)
              allow(ServiceBinding).to receive(:first).with(service_instance: service_instance2, app: app).and_return(nil)

              # Second request, should fail with correct error
              expect do
                action.precursor(service_instance2, app:, message:)
              end.to raise_error(ServiceBindingCreate::UnprocessableCreate,
                                 "The binding name is invalid. App binding names must be unique. The app already has a binding with name 'foo'.")
            end
          end

          context 'when creating bindings with the same service instance concurrently' do
            let(:name2) { 'foo2' }
            let(:message2) do
              VCAP::CloudController::ServiceCredentialAppBindingCreateMessage.new(
                {
                  name: name2
                }
              )
            end

            it 'raises an error when the app is already bound to the service instance' do
              # First request, should succeed
              expect do
                action.precursor(service_instance, app:, message:)
              end.not_to raise_error

              # Mock the validation for the second request to simulate the race condition and trigger a
              # unique constraint violation on service_instance_guid + app_guid
              allow_any_instance_of(ServiceBinding).to receive(:validate).and_return(true)
              allow(ServiceBinding).to receive(:first).with(service_instance:, app:).and_return(nil)

              # Second request, should fail with correct error
              expect do
                action.precursor(service_instance, app: app, message: message2)
              end.to raise_error(ServiceBindingCreate::UnprocessableCreate, 'The app is already bound to the service instance.')
            end
          end

          it 'raises an error when the app and the instance are in different spaces' do
            another_space = Space.make
            another_app = AppModel.make(space: another_space)
            expect { action.precursor(service_instance, app: another_app, message: message) }.to raise_error(
              ServiceCredentialBindingAppCreate::UnprocessableCreate,
              'The service instance and the app are in different spaces'
            )
          end
        end

        context 'user-provided service instance' do
          let(:si_details) do
            {
              space: space,
              name: 'instance_name',
              credentials: { 'password' => 'rennt', 'username' => 'lola' },
              syslog_drain_url: 'https://drain.syslog.example.com/runlolarun'
            }
          end
          let(:service_instance) { UserProvidedServiceInstance.make(**si_details) }

          it_behaves_like 'the credential binding precursor'
        end

        context 'managed service instance' do
          let(:si_details) do
            {
              space:
            }
          end

          let(:service_instance) { ManagedServiceInstance.make(**si_details) }

          context 'validations' do
            context 'when plan is not bindable' do
              before do
                service_instance.service_plan.update(bindable: false)
              end

              it 'raises an error' do
                expect { action.precursor(service_instance, app:, message:) }.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'Service plan does not allow bindings'
                )
              end
            end

            context 'when plan is not available' do
              before do
                service_instance.service_plan.update(active: false)
              end

              it 'does not raise an error' do
                expect do
                  action.precursor(service_instance, app: app, volume_mount_services_enabled: true, message: message)
                end.not_to raise_error
              end
            end

            context 'when the service is a volume service and service volume mounting is disabled' do
              let(:service_instance) { ManagedServiceInstance.make(:volume_mount, **si_details) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app: app, volume_mount_services_enabled: false, message: message)
                end.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'Support for volume mount services is disabled'
                )
              end
            end

            context 'when there is an operation in progress for the service instance' do
              it 'raises an error' do
                service_instance.save_with_new_operation({}, { type: 'tacos', state: 'in progress' })

                expect do
                  action.precursor(service_instance, app: app, volume_mount_services_enabled: false, message: message)
                end.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'There is an operation in progress for the service instance'
                )
              end
            end

            context "when the service instance is in state 'create failed'" do
              it 'raises an error' do
                service_instance.save_with_new_operation({}, { type: 'create', state: 'failed' })

                expect do
                  action.precursor(service_instance, app: app, volume_mount_services_enabled: false, message: message)
                end.to raise_error(
                  ServiceCredentialBindingAppCreate::UnprocessableCreate,
                  'Service instance not found'
                )
              end
            end

            context 'when the service is a volume service and service volume mounting is enabled' do
              let(:service_instance) { ManagedServiceInstance.make(:volume_mount, **si_details) }

              it 'does not raise an error' do
                expect do
                  action.precursor(service_instance, app: app, volume_mount_services_enabled: true, message: message)
                end.not_to raise_error
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

      describe '#bind' do
        let(:precursor) { action.precursor(service_instance, app:, message:) }
        let(:details) do
          {
            credentials: { 'password' => 'rennt', 'username' => 'lola' },
            syslog_drain_url: 'https://drain.syslog.example.com/runlolarun'
          }
        end
        let(:bind_response) { { binding: details } }

        it_behaves_like 'service binding creation', ServiceBinding

        describe 'app specific behaviour' do
          context 'managed service instance' do
            let(:service_offering) { Service.make(bindings_retrievable: true) }
            let(:service_plan) { ServicePlan.make(service: service_offering) }
            let(:service_instance) { ManagedServiceInstance.make(space:, service_plan:) }
            let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: bind_response) }

            before do
              allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
            end

            it_behaves_like 'the sync credential binding', ServiceBinding, true

            context 'manifest triggered' do
              let(:manifest_triggered) { true }

              it 'logs an audit event with manifest triggered in true' do
                action.bind(precursor)
                expect(binding_event_repo).to have_received(:record_create).with(
                  precursor,
                  user_audit_info,
                  audit_hash,
                  manifest_triggered: true
                )
              end
            end

            context 'asynchronous binding' do
              let(:broker_provided_operation) { Sham.guid }
              let(:bind_async_response) { { async: true, operation: broker_provided_operation } }
              let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: bind_async_response) }

              it 'logs audit start_create' do
                action.bind(precursor)
                expect(binding_event_repo).to have_received(:record_start_create).with(
                  precursor,
                  user_audit_info,
                  audit_hash,
                  manifest_triggered: false
                )
              end

              context 'manifest triggered' do
                let(:manifest_triggered) { true }

                it 'logs an audit event with manifest triggered in true' do
                  action.bind(precursor)
                  expect(binding_event_repo).to have_received(:record_start_create).with(
                    precursor,
                    user_audit_info,
                    audit_hash,
                    manifest_triggered: true
                  )
                end
              end
            end
          end

          context 'user-provided service instance' do
            let(:details) do
              {
                space: space,
                credentials: { 'password' => 'rennt', 'username' => 'lola' },
                syslog_drain_url: 'https://drain.syslog.example.com/runlolarun'
              }
            end
            let(:service_instance) { UserProvidedServiceInstance.make(**details) }

            it_behaves_like 'the sync credential binding', ServiceBinding, true

            context 'manifest triggered' do
              let(:manifest_triggered) { true }

              it 'logs an audit event with manifest triggered in true' do
                action.bind(precursor)
                expect(binding_event_repo).to have_received(:record_create).with(
                  precursor,
                  user_audit_info,
                  audit_hash,
                  manifest_triggered: true
                )
              end
            end
          end
        end
      end

      describe '#poll' do
        let(:original_name) { name }
        let(:binding) { action.precursor(service_instance, app:, message:) }
        let(:volume_mounts) do
          [{
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
        end
        let(:syslog_drain_url) { 'https://drain.syslog.example.com/runlolarun' }

        it_behaves_like 'polling service credential binding creation'
      end
    end
  end
end
