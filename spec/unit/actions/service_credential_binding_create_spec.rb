require 'db_spec_helper'
require 'actions/service_credential_binding_create'
require 'cloud_controller/user_audit_info'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceCredentialBindingCreate do
      subject(:action) do
        described_class.new(
          user_audit_info,
          volume_mount_services_enabled
        )
      end

      let(:volume_mount_services_enabled) { true }
      let(:space) { Space.make }
      let(:app) { AppModel.make(space: space) }
      let(:binding_details) {}
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'run@lola.run', user_guid: '100_000') }

      before do
        @service_binding_event_repository = Repositories::ServiceBindingEventRepository
        allow(@service_binding_event_repository).to receive(:record_create)
      end

      describe '#precursor' do
        RSpec.shared_examples 'the credential binding precursor' do
          it 'returns a service credential binding precursor' do
            binding = action.precursor(service_instance, app: app, name: details[:name])
            expect(binding).to be
            expect(binding).to eq(ServiceBinding.first)
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
              ServiceCredentialBindingCreate::UnprocessableCreate,
              'No app was specified'
            )
          end

          it 'raises an error when a binding already exists' do
            ServiceBinding.make(service_instance: service_instance, app: app)
            expect { action.precursor(service_instance, app: app, name: details[:name]) }.to raise_error(
              ServiceCredentialBindingCreate::UnprocessableCreate,
              'The app is already bound to the service instance'
            )
          end

          it 'raises an error when a the app and the instance are in different spaces' do
            another_space = Space.make
            another_app = AppModel.make(space: another_space)
            expect { action.precursor(service_instance, app: another_app, name: details[:name]) }.to raise_error(
              ServiceCredentialBindingCreate::UnprocessableCreate,
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

          context 'when plan is not bindable' do
            before do
              service_instance.service_plan.update(bindable: false)
            end

            it 'raises an error' do
              expect { action.precursor(service_instance, app: app) }.to raise_error(
                ServiceCredentialBindingCreate::UnprocessableCreate,
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
                ServiceCredentialBindingCreate::UnprocessableCreate,
                'Service plan is not available'
              )
            end
          end

          context 'when the service is a volume service and service volume mounting is disabled' do
            let(:volume_mount_services_enabled) { false }
            let(:service_instance) { ManagedServiceInstance.make(:volume_mount, **details) }

            it 'raises an error' do
              expect { action.precursor(service_instance, app: app) }.to raise_error(
                ServiceCredentialBindingCreate::UnprocessableCreate,
                'Support for volume mount services is disabled'
              )
            end
          end

          context 'when binding from an app in a shared space' do
            let(:other_space) { Space.make }
            let(:service_instance) do
              ManagedServiceInstance.make(space: other_space).tap do |si|
                si.add_shared_space(space)
              end
            end

            it 'raises an error that it is not implemented' do
              expect { action.precursor(service_instance, app: app) }.to raise_error(
                ServiceCredentialBindingCreate::Unimplemented,
                'Cannot create credential bindings for managed service instances'
              )
            end
          end

          context 'when successful' do
            it 'raises an error that it is not implemented' do
              expect { action.precursor(service_instance, app: app) }.to raise_error(
                ServiceCredentialBindingCreate::Unimplemented,
                'Cannot create credential bindings for managed service instances'
              )
            end
          end
        end
      end

      describe '#bind' do
        let(:precursor) { action.precursor(service_instance, app: app) }

        RSpec.shared_examples 'the credential binding bind' do
          it 'creates and returns the credential binding' do
            action.bind(precursor)

            precursor.reload
            expect(precursor).to eq(ServiceBinding.first)
            expect(precursor.credentials).to eq(details[:credentials])
            expect(precursor.syslog_drain_url).to eq(details[:syslog_drain_url])
            expect(precursor.last_operation.type).to eq('create')
            expect(precursor.last_operation.state).to eq('succeeded')
          end

          it 'creates an audit event' do
            action.bind(precursor)
            expect(@service_binding_event_repository).to have_received(:record_create).with(precursor, user_audit_info, manifest_triggered: false)
          end

          context 'when saving to the db fails' do
            it 'fails the binding operation' do
              allow(precursor).to receive(:save_with_new_operation).with({ type: 'create', state: 'succeeded' }, attributes: anything).and_raise(Sequel::ValidationFailed, 'Meh')
              allow(precursor).to receive(:save_with_new_operation).with({ type: 'create', state: 'failed', description: 'Meh' }).and_call_original
              expect { action.bind(precursor) }.to raise_error(Sequel::ValidationFailed, 'Meh')
              precursor.reload
              expect(precursor.last_operation.type).to eq('create')
              expect(precursor.last_operation.state).to eq('failed')
              expect(precursor.last_operation.description).to eq('Meh')
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

          it_behaves_like 'the credential binding bind'
        end
      end
    end
  end
end
