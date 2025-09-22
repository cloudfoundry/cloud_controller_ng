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
          before { TestConfig.override(max_service_credential_bindings_per_app_service_instance: 1) }

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
            expect do
              action.precursor(service_instance, message:)
            end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'No app was specified')
          end

          context 'when a binding already exists' do
            let!(:binding) { ServiceBinding.make(service_instance:, app:) }

            context 'when no last binding operation exists' do
              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'The app is already bound to the service instance')
              end
            end

            context "when the last binding operation is in 'create failed' state" do
              let(:fake_orphan_mitigator) { instance_double(VCAP::Services::ServiceBrokers::V2::OrphanMitigator) }

              before do
                binding.save_with_attributes_and_new_operation({}, { type: 'create', state: 'failed' })
                allow(VCAP::Services::ServiceBrokers::V2::OrphanMitigator).to receive(:new).and_return(fake_orphan_mitigator)
                allow(fake_orphan_mitigator).to receive(:cleanup_failed_bind).with(binding)
              end

              it 'deletes the existing binding and creates a new one' do
                b = action.precursor(service_instance, app:, message:)

                expect(b.guid).not_to eq(binding.guid)
                expect(b).to be_create_in_progress
                expect { binding.reload }.to raise_error Sequel::NoExistingObject
                expect(fake_orphan_mitigator).to have_received(:cleanup_failed_bind).with(binding)
              end
            end

            context "when the last binding operation is in 'create in progress' state" do
              before { binding.save_with_attributes_and_new_operation({}, { type: 'create', state: 'in progress' }) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'The app is already bound to the service instance')
              end
            end

            context "when the last binding operation is in 'create succeeded' state" do
              before { binding.save_with_attributes_and_new_operation({}, { type: 'create', state: 'succeeded' }) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'The app is already bound to the service instance')
              end
            end

            context "when the last binding operation is in 'delete failed' state" do
              before { binding.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'failed' }) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'The binding is getting deleted or its deletion failed')
              end
            end

            context "when the last binding operation is in 'delete in progress' state" do
              before { binding.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'in progress' }) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'The binding is getting deleted or its deletion failed')
              end
            end
          end

          context 'app_guid + name uniqueness validation' do
            let!(:other_binding) { ServiceBinding.make(service_instance: other_service_instance, app: app, name: name) }

            context 'two bindings with the same binding name' do
              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceBindingCreate::UnprocessableCreate,
                                   "The binding name is invalid. Binding names must be unique for a given service instance and app. The app already has a binding with name 'foo'.")
              end
            end

            context 'two bindings without binding name' do
              let(:name) { nil }

              it 'does not raise an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.not_to raise_error
              end
            end
          end

          context 'when app and service instance are in different spaces' do
            let(:different_space) { Space.make }
            let(:app) { AppModel.make(space: different_space) }

            it 'raises an error' do
              expect do
                action.precursor(service_instance, app:, message:)
              end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'The service instance and the app are in different spaces')
            end
          end

          context 'concurrent credential binding creation' do
            it 'allows only one binding when two creates run in parallel' do
              # This test simulates a race condition for concurrent binding creation using a spy on `app`.
              # We mock that a second binding is created after the first one acquires a lock and expect an `UnprocessableCreate` error.
              allow(app).to receive(:lock!).and_wrap_original do |m, *args, &block|
                m.call(*args, &block)
                ServiceBinding.make(service_instance:, app:)
              end

              expect do
                action.precursor(service_instance, app:, message:)
              end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'The app is already bound to the service instance')

              expect(app).to have_received(:lock!)
            end
          end

          context 'when multiple bindings are allowed' do
            let(:binding_1) { ServiceBinding.make(service_instance:, app:, name:) }
            let(:binding_2) { ServiceBinding.make(service_instance:, app:, name:) }

            before do
              TestConfig.override(max_service_credential_bindings_per_app_service_instance: 3)
              binding_1.save_with_attributes_and_new_operation({}, { type: 'create', state: 'succeeded' })
              binding_2.save_with_attributes_and_new_operation({}, { type: 'create', state: 'succeeded' })
            end

            it 'creates multiple bindings for the same app and service instance' do
              expect do
                action.precursor(service_instance, app:, message:)
              end.to change { ServiceBinding.where(app:, service_instance:).count }.from(2).to(3)
            end

            context "when an existing binding is in 'create failed' state" do
              let(:fake_orphan_mitigator) { instance_double(VCAP::Services::ServiceBrokers::V2::OrphanMitigator) }

              before do
                binding_1.save_with_attributes_and_new_operation({}, { type: 'create', state: 'failed' })
                allow(VCAP::Services::ServiceBrokers::V2::OrphanMitigator).to receive(:new).and_return(fake_orphan_mitigator)
                allow(fake_orphan_mitigator).to receive(:cleanup_failed_bind).with(binding_1)
              end

              it 'deletes the failed binding, does not change other existing bindings and creates a new one' do
                b = action.precursor(service_instance, app:, message:)

                expect(b.guid).not_to eq(binding_1.guid)
                expect(b).to be_create_in_progress
                expect { binding_1.reload }.to raise_error Sequel::NoExistingObject
                expect(fake_orphan_mitigator).to have_received(:cleanup_failed_bind).with(binding_1)
                expect(binding_2.reload).to be_create_succeeded
              end
            end

            context "when an existing binding is in 'create in progress' state" do
              before { binding_1.save_with_attributes_and_new_operation({}, { type: 'create', state: 'in progress' }) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate,
                                   "There is already a binding in progress for this service instance and app (binding guid: #{binding_1.guid})")
              end
            end

            context "when an existing binding is in 'delete failed' state" do
              before { binding_1.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'failed' }) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'A binding for this service instance and app is getting deleted or its deletion failed')
              end
            end

            context "when an existing binding is in 'delete in progress' state" do
              before { binding_1.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'in progress' }) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'A binding for this service instance and app is getting deleted or its deletion failed')
              end
            end

            context 'when changing the binding name' do
              let(:message) { VCAP::CloudController::ServiceCredentialAppBindingCreateMessage.new({ name: 'bar' }) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'The binding name cannot be changed for the same app and service instance')
              end
            end

            context 'when the bindings limit per app and service instance is reached' do
              before { TestConfig.override(max_service_credential_bindings_per_app_service_instance: 2) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate,
                                   'The app has too many bindings to this service instance (limit: 2). Consider deleting existing/orphaned bindings.')
              end
            end
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
          let(:other_service_instance) { UserProvidedServiceInstance.make(**si_details, name: 'other_instance_name') }

          it_behaves_like 'the credential binding precursor'
        end

        context 'managed service instance' do
          let(:si_details) do
            {
              space: space,
              name: 'instance_name'
            }
          end

          let(:service_instance) { ManagedServiceInstance.make(**si_details) }
          let(:other_service_instance) { ManagedServiceInstance.make(**si_details, name: 'other_instance_name') }

          it_behaves_like 'the credential binding precursor'

          context 'when binding from an app in a shared space' do
            let(:other_space) { Space.make }
            let(:service_instance) { ManagedServiceInstance.make(**si_details, space: other_space) }

            before { service_instance.add_shared_space(space) }

            it_behaves_like 'the credential binding precursor'
          end

          context 'validations' do
            context 'when plan is not bindable' do
              before { service_instance.service_plan.update(bindable: false) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'Service plan does not allow bindings')
              end
            end

            context 'when plan is not available' do
              before { service_instance.service_plan.update(active: false) }

              it 'does not raise an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.not_to raise_error
              end
            end

            context 'when the service is a volume service and service volume mounting is disabled' do
              let(:service_instance) { ManagedServiceInstance.make(:volume_mount, **si_details) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app: app, message: message, volume_mount_services_enabled: false)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'Support for volume mount services is disabled')
              end
            end

            context 'when the service is a volume service and service volume mounting is enabled' do
              let(:service_instance) { ManagedServiceInstance.make(:volume_mount, **si_details) }

              it 'does not raise an error' do
                expect do
                  action.precursor(service_instance, app: app, message: message, volume_mount_services_enabled: true)
                end.not_to raise_error
              end
            end

            context 'when there is an operation in progress for the service instance' do
              before { service_instance.save_with_new_operation({}, { type: 'tacos', state: 'in progress' }) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'There is an operation in progress for the service instance')
              end
            end

            context "when the service instance is in state 'create failed'" do
              before { service_instance.save_with_new_operation({}, { type: 'create', state: 'failed' }) }

              it 'raises an error' do
                expect do
                  action.precursor(service_instance, app:, message:)
                end.to raise_error(ServiceCredentialBindingAppCreate::UnprocessableCreate, 'Service instance not found')
              end
            end
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
