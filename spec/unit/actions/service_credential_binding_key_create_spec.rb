require 'spec_helper'
require 'actions/service_credential_binding_key_create'
require 'support/shared_examples/v3_service_binding_create'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceCredentialBindingKeyCreate do
      subject(:action) { described_class.new(user_audit_info, audit_hash) }

      let(:audit_hash) { { some_info: 'some_value' } }
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'run@lola.run', user_guid: '100_000') }
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:binding_details) {}
      let(:name) { 'test-key' }
      let(:binding_event_repo) { instance_double(Repositories::ServiceGenericBindingEventRepository) }

      before do
        allow(Repositories::ServiceGenericBindingEventRepository).to receive(:new).with('service_key').and_return(binding_event_repo)
        allow(binding_event_repo).to receive(:record_create)
        allow(binding_event_repo).to receive(:record_start_create)
      end

      describe '#precursor' do
        RSpec.shared_examples 'the credential binding precursor' do
          it 'returns a service credential binding precursor' do
            binding = action.precursor(service_instance, name)

            expect(binding).to be
            expect(binding).to eq(ServiceKey.where(guid: binding.guid).first)
            expect(binding.service_instance).to eq(service_instance)
            expect(binding.name).to eq(name)
            expect(binding.credentials).to be_empty
          end

          it 'raises an error when a key with same name already exists' do
            binding = ServiceKey.make(service_instance: service_instance)
            expect { action.precursor(service_instance, binding.name) }.to raise_error(
              ServiceCredentialBindingKeyCreate::UnprocessableCreate,
              "The binding name is invalid. Key binding names must be unique. The service instance already has a key binding with name '#{binding.name}'."
            )
          end
        end

        context 'user-provided service instance' do
          let(:service_instance) { UserProvidedServiceInstance.make }

          it 'raises error' do
            expect { action.precursor(service_instance, name) }.to raise_error(
              ServiceCredentialBindingKeyCreate::UnprocessableCreate,
              "Service credential bindings of type 'key' are not supported for user-provided service instances."
            )
          end
        end

        context 'managed service instance' do
          let(:service_instance) { ManagedServiceInstance.make(space: space) }

          context 'validations' do
            context 'when plan is not bindable' do
              before do
                service_instance.service_plan.update(bindable: false)
              end

              it 'raises an error' do
                expect { action.precursor(service_instance, name) }.to raise_error(
                  ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                  'Service plan does not allow bindings.'
                )
              end
            end

            context 'when plan is not available' do
              before do
                service_instance.service_plan.update(active: false)
              end

              it 'raises an error' do
                expect { action.precursor(service_instance, name) }.to raise_error(
                  ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                  'Service plan is not available.'
                )
              end
            end

            context 'when there is an operation in progress for the service instance' do
              it 'raises an error' do
                service_instance.save_with_new_operation({}, { type: 'tacos', state: 'in progress' })

                expect {
                  action.precursor(service_instance, name)
                }.to raise_error(
                  ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                  'There is an operation in progress for the service instance.'
                )
              end
            end

            context 'when the name is taken' do
              let(:existing_service_key) { ServiceKey.make(service_instance: service_instance) }

              it 'raises an error' do
                expect { action.precursor(service_instance, existing_service_key.name) }.to raise_error(
                  ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                  "The binding name is invalid. Key binding names must be unique. The service instance already has a key binding with name '#{existing_service_key.name}'."
                )
              end
            end
          end

          context 'when successful' do
            it_behaves_like 'the credential binding precursor'
          end
        end

        context 'quotas' do
          let(:service_instance) { ManagedServiceInstance.make(space: space) }

          context 'when service key limit has been reached for the space' do
            before do
              quota = SpaceQuotaDefinition.make(total_service_keys: 1, organization: org)
              quota.add_space(space)
              ServiceKey.make(service_instance: service_instance)
            end

            it 'raises an error' do
              expect { action.precursor(service_instance, name) }.to raise_error(
                ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                "You have exceeded your space's limit for service binding of type key."
              )
            end
          end

          context 'when service key limit has been reached for the org' do
            before do
              quotas = QuotaDefinition.make(total_service_keys: 1)
              quotas.add_organization(org)
              ServiceKey.make(service_instance: service_instance)
            end

            it 'raises an error' do
              expect { action.precursor(service_instance, name) }.to raise_error(
                ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                "You have exceeded your organization's limit for service binding of type key."
              )
            end
          end
        end
      end

      context '#bind' do
        let(:app) { nil }
        let(:precursor) { action.precursor(service_instance, name) }
        let(:specific_fields) { {} }
        let(:details) {
          {
            credentials: { 'password' => 'rennt', 'username' => 'lola' }
          }.merge(specific_fields)
        }
        let(:bind_response) { { binding: details } }

        it_behaves_like 'service binding creation', ServiceKey

        describe 'key specific behaviour' do
          context 'managed service instance' do
            let(:service_offering) { Service.make(bindings_retrievable: true) }
            let(:service_plan) { ServicePlan.make(service: service_offering) }
            let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
            let(:broker_client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: bind_response) }

            before do
              allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(broker_client)
            end

            it_behaves_like 'the sync credential binding', ServiceKey

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
        end
      end

      describe '#poll' do
        # TODO: extract and reuse from credential bindings type app
        let(:binding) { action.precursor(service_instance, 'original-name') }
        let(:credentials) { { 'password' => 'rennt', 'username' => 'lola' } }
        let(:volume_mounts) { nil }
        let(:syslog_drain_url) { nil }
        let(:fetch_binding_response) { { credentials: credentials, name: 'updated-name' } }

        it_behaves_like 'polling service binding creation'

        describe 'key specific behaviour' do
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

            it 'fetches the service binding and updates only the credentials' do
              action.poll(binding)

              expect(broker_client).to have_received(:fetch_service_binding).with(binding)

              binding.reload
              expect(binding.credentials).to eq(credentials)
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
