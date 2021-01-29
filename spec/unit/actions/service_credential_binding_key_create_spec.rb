require 'spec_helper'
require 'actions/service_credential_binding_key_create'
require 'support/shared_examples/v3_service_binding_create'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceCredentialBindingKeyCreate do
      subject(:action) { described_class.new(user_audit_info, audit_hash) }

      let(:audit_hash) { { some_info: 'some_value' } }
      let(:user_guid) { Sham.uaa_id }
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'run@lola.run', user_guid: user_guid) }
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:binding_details) {}
      let(:name) { 'test-key' }
      let(:binding_event_repo) { instance_double(Repositories::ServiceGenericBindingEventRepository) }
      let(:name) { 'some-binding-name' }
      let(:message) {
        VCAP::CloudController::ServiceCredentialKeyBindingCreateMessage.new(
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
      }

      before do
        allow(Repositories::ServiceGenericBindingEventRepository).to receive(:new).with('service_key').and_return(binding_event_repo)
        allow(binding_event_repo).to receive(:record_create)
        allow(binding_event_repo).to receive(:record_start_create)
      end

      describe '#precursor' do
        RSpec.shared_examples 'the credential binding precursor' do
          it 'returns a service credential binding precursor' do
            binding = action.precursor(service_instance, message: message)

            expect(binding).to_not be_nil
            expect(binding).to eq(ServiceKey.where(guid: binding.guid).first)
            expect(binding.service_instance).to eq(service_instance)
            expect(binding.name).to eq(name)
            expect(binding.credentials).to be_empty
            expect(binding.last_operation.type).to eq('create')
            expect(binding.last_operation.state).to eq('in progress')
            expect(binding).to have_labels({ prefix: nil, key: 'release', value: 'stable' })
            expect(binding).to have_annotations({ prefix: 'seriouseats.com', key: 'potato', value: 'fried' })
          end

          it 'raises an error when a key with same name already exists' do
            binding = ServiceKey.make(service_instance: service_instance, name: message.name)
            expect { action.precursor(service_instance, message: message) }.to raise_error(
              ServiceCredentialBindingKeyCreate::UnprocessableCreate,
              "The binding name is invalid. Key binding names must be unique. The service instance already has a key binding with name '#{binding.name}'."
            )
          end
        end

        context 'user-provided service instance' do
          let(:service_instance) { UserProvidedServiceInstance.make }

          it 'raises error' do
            expect { action.precursor(service_instance, message: message) }.to raise_error(
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
                expect { action.precursor(service_instance, message: message) }.to raise_error(
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
                expect { action.precursor(service_instance, message: message) }.to raise_error(
                  ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                  'Service plan is not available.'
                )
              end
            end

            context 'when there is an operation in progress for the service instance' do
              it 'raises an error' do
                service_instance.save_with_new_operation({}, { type: 'tacos', state: 'in progress' })

                expect {
                  action.precursor(service_instance, message: message)
                }.to raise_error(
                  ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                  'There is an operation in progress for the service instance.'
                )
              end
            end

            context 'when the name is taken' do
              let(:existing_service_key) { ServiceKey.make(service_instance: service_instance, name: message.name) }

              it 'raises an error' do
                expect { action.precursor(service_instance, message: message) }.to raise_error(
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
              expect { action.precursor(service_instance, message: message) }.to raise_error(
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
              expect { action.precursor(service_instance, message: message) }.to raise_error(
                ServiceCredentialBindingKeyCreate::UnprocessableCreate,
                "You have exceeded your organization's limit for service binding of type key."
              )
            end
          end
        end
      end

      context '#bind' do
        let(:app) { nil }
        let(:precursor) { action.precursor(service_instance, message: message) }
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
                  manifest_triggered: false
                )
              end
            end
          end
        end
      end

      describe '#poll' do
        let(:original_name) { name }
        let(:binding) { action.precursor(service_instance, message: message) }
        let(:volume_mounts) { nil }
        let(:syslog_drain_url) { nil }

        it_behaves_like 'polling service credential binding creation'
      end
    end
  end
end
