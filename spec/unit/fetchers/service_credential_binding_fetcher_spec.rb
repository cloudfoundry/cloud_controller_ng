require 'db_spec_helper'
require 'fetchers/service_credential_binding_fetcher'

module VCAP
  module CloudController
    RSpec.describe ServiceCredentialBindingFetcher do
      let(:fetcher) { ServiceCredentialBindingFetcher.new }

      describe 'not a real guid' do
        let!(:existing_credential_binding) { ServiceBinding.make }

        it 'returns nothing' do
          credential_binding = fetcher.fetch('does-not-exist', readable_spaces_query: nil)
          expect(credential_binding).to be_nil
        end
      end

      describe 'service keys' do
        let(:space) { Space.make }
        let(:readable_spaces_query) { VCAP::CloudController::Space.where(id: [space].map(&:id)) }
        let(:service_instance) { ManagedServiceInstance.make(space:) }
        let!(:service_key) { ServiceKey.make(service_instance:) }

        describe 'when in the space' do
          it 'can be found' do
            credential_binding = fetcher.fetch(service_key.guid, readable_spaces_query:)

            expect(credential_binding).not_to be_nil
            expect(credential_binding).to an_instance_of(VCAP::CloudController::ServiceKey)
            expect(credential_binding.name).to eql(service_key.name)
            expect(credential_binding.created_at).to eql(service_key.created_at)
            expect(credential_binding.updated_at).to eql(service_key.updated_at)
            expect(credential_binding.service_instance_guid).to eql(service_instance.guid)
          end
        end

        describe 'when not in the space' do
          let!(:other_space) { Space.make }
          let!(:readable_spaces_query) { VCAP::CloudController::Space.where(id: [other_space].map(&:id)) }

          it 'can not be found' do
            credential_binding = fetcher.fetch(service_key.guid, readable_spaces_query:)

            expect(credential_binding).to be_nil
          end
        end
      end

      describe 'app bindings' do
        describe 'managed services' do
          let(:space) { Space.make }
          let(:readable_spaces_query) { VCAP::CloudController::Space.where(id: [space].map(&:id)) }
          let(:service_instance) { ManagedServiceInstance.make(space:) }
          let!(:app_binding) { ServiceBinding.make(service_instance: service_instance, name: 'some-name') }

          it 'can be found' do
            credential_binding = fetcher.fetch(app_binding.guid, readable_spaces_query:)

            expect(credential_binding).not_to be_nil
            expect(credential_binding).to an_instance_of(VCAP::CloudController::ServiceBinding)
            expect(credential_binding.name).to eql('some-name')
            expect(credential_binding.created_at).to eql(app_binding.created_at)
            expect(credential_binding.updated_at).to eql(app_binding.updated_at)
            expect(credential_binding.service_instance_guid).to eql(service_instance.guid)
            expect(credential_binding.app_guid).to eql(app_binding.app_guid)
            expect(credential_binding.last_operation).to be_nil
          end

          describe 'when not in the space' do
            let!(:other_space) { Space.make }
            let!(:readable_spaces_query) { VCAP::CloudController::Space.where(id: [other_space].map(&:id)) }

            it 'can not be found' do
              credential_binding = fetcher.fetch(app_binding.guid, readable_spaces_query:)

              expect(credential_binding).to be_nil
            end
          end
        end

        describe 'user provided services' do
          let(:space) { Space.make }
          let(:readable_spaces_query) { VCAP::CloudController::Space.where(id: [space].map(&:id)) }
          let(:service_instance) { UserProvidedServiceInstance.make(space:) }
          let!(:app_binding) { ServiceBinding.make(service_instance: service_instance, name: 'some-name') }

          it 'can be found' do
            credential_binding = fetcher.fetch(app_binding.guid, readable_spaces_query:)

            expect(credential_binding).not_to be_nil
            expect(credential_binding).to an_instance_of(VCAP::CloudController::ServiceBinding)
            expect(credential_binding.name).to eql('some-name')
            expect(credential_binding.created_at).to eql(app_binding.created_at)
            expect(credential_binding.updated_at).to eql(app_binding.updated_at)
            expect(credential_binding.service_instance_guid).to eql(service_instance.guid)
            expect(credential_binding.app_guid).to eql(app_binding.app_guid)
            expect(credential_binding.last_operation).to be_nil
          end

          describe 'when not in the space' do
            let!(:other_space) { Space.make }
            let!(:readable_spaces_query) { VCAP::CloudController::Space.where(id: [other_space].map(&:id)) }

            it 'can not be found' do
              credential_binding = fetcher.fetch(app_binding.guid, readable_spaces_query:)

              expect(credential_binding).to be_nil
            end
          end
        end

        describe 'with last operation' do
          let(:service_instance) { ManagedServiceInstance.make }
          let(:readable_spaces_query) { VCAP::CloudController::Space.where(id: [service_instance.space].map(&:id)) }
          let!(:app_binding) do
            binding = ServiceBinding.make(service_instance:)
            binding.save_with_new_operation({ state: 'succeeded', type: 'create', description: 'radical avocado' })
            binding
          end

          it 'fetches the last operation' do
            credential_binding = fetcher.fetch(app_binding.guid, readable_spaces_query:)

            expect(credential_binding.last_operation).not_to be_nil

            last_operation = credential_binding.last_operation

            expect(last_operation.type).to eql('create')
            expect(last_operation.state).to eql('succeeded')
            expect(last_operation.description).to eql('radical avocado')
            expect(last_operation.created_at).to eql(app_binding.last_operation.created_at)
            expect(last_operation.updated_at).to eql(app_binding.last_operation.updated_at)
          end
        end
      end
    end
  end
end
