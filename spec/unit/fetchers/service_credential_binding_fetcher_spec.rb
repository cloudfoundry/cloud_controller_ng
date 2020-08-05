require 'spec_helper'
require 'fetchers/service_credential_binding_fetcher'

module VCAP
  module CloudController
    RSpec.describe ServiceCredentialBindingFetcher do
      let(:fetcher) { ServiceCredentialBindingFetcher.new }

      describe 'not a real guid' do
        let!(:existing_credential_binding) { ServiceBinding.make }

        it 'should return nothing' do
          credential_binding = fetcher.fetch('does-not-exist', space_guids: :all)
          expect(credential_binding).to be_nil
        end
      end

      describe 'service keys' do
        let(:type) { 'key' }
        let(:space) { Space.make }
        let(:service_instance) { ManagedServiceInstance.make(space: space) }
        let!(:service_key) { ServiceKey.make(service_instance: service_instance) }

        describe 'when in the space' do
          it 'can be found' do
            credential_binding = fetcher.fetch(service_key.guid, space_guids: [space.guid])

            expect(credential_binding).not_to be_nil
            expect(credential_binding.type).to eql(type)
            expect(credential_binding.name).to eql(service_key.name)
            expect(credential_binding.created_at).to eql(service_key.created_at)
            expect(credential_binding.updated_at).to eql(service_key.updated_at)
            expect(credential_binding.service_instance_guid).to eql(service_instance.guid)
            expect(credential_binding.app_guid).to be_nil
            expect(credential_binding.last_operation_id).to be_nil
          end
        end

        describe 'when not in the space' do
          let!(:other_space) { Space.make }
          it 'can not be found' do
            credential_binding = fetcher.fetch(service_key.guid, space_guids: [other_space.guid])

            expect(credential_binding).to be_nil
          end
        end
      end

      describe 'app bindings' do
        let(:type) { 'app' }

        describe 'managed services' do
          let(:space) { Space.make }
          let(:service_instance) { ManagedServiceInstance.make(space: space) }
          let!(:app_binding) { ServiceBinding.make(service_instance: service_instance, name: 'some-name') }

          it 'can be found' do
            credential_binding = fetcher.fetch(app_binding.guid, space_guids: [space.guid])

            expect(credential_binding).not_to be_nil
            expect(credential_binding.type).to eql(type)
            expect(credential_binding.name).to eql('some-name')
            expect(credential_binding.created_at).to eql(app_binding.created_at)
            expect(credential_binding.updated_at).to eql(app_binding.updated_at)
            expect(credential_binding.service_instance_guid).to eql(service_instance.guid)
            expect(credential_binding.app_guid).to eql(app_binding.app_guid)
            expect(credential_binding.last_operation_id).to be_nil
          end

          describe 'when not in the space' do
            let!(:other_space) { Space.make }
            it 'can not be found' do
              credential_binding = fetcher.fetch(app_binding.guid, space_guids: [other_space.guid])

              expect(credential_binding).to be_nil
            end
          end
        end

        describe 'user provided services' do
          let(:space) { Space.make }
          let(:service_instance) { UserProvidedServiceInstance.make(space: space) }
          let!(:app_binding) { ServiceBinding.make(service_instance: service_instance, name: 'some-name') }

          it 'can be found' do
            credential_binding = fetcher.fetch(app_binding.guid, space_guids: [space.guid])

            expect(credential_binding).not_to be_nil
            expect(credential_binding.type).to eql(type)
            expect(credential_binding.name).to eql('some-name')
            expect(credential_binding.created_at).to eql(app_binding.created_at)
            expect(credential_binding.updated_at).to eql(app_binding.updated_at)
            expect(credential_binding.service_instance_guid).to eql(service_instance.guid)
            expect(credential_binding.app_guid).to eql(app_binding.app_guid)
            expect(credential_binding.last_operation_id).to be_nil
          end

          describe 'when not in the space' do
            let!(:other_space) { Space.make }
            it 'can not be found' do
              credential_binding = fetcher.fetch(app_binding.guid, space_guids: [other_space.guid])

              expect(credential_binding).to be_nil
            end
          end
        end

        describe 'with last operation' do
          let(:service_instance) { ManagedServiceInstance.make }
          let!(:app_binding) {
            binding = ServiceBinding.make(service_instance: service_instance)
            binding.save_with_new_operation({ state: 'succeeded', type: 'create', description: 'radical avocado' })
            binding
          }
          it 'fetches the last operation' do
            credential_binding = fetcher.fetch(app_binding.guid, space_guids: [service_instance.space.guid])

            expect(credential_binding.last_operation_id).to_not be_nil
            expect(credential_binding.last_operation_type).to eql('create')
            expect(credential_binding.last_operation_state).to eql('succeeded')
            expect(credential_binding.last_operation_description).to eql('radical avocado')
            expect(credential_binding.last_operation_created_at).to eql(app_binding.last_operation.created_at)
            expect(credential_binding.last_operation_updated_at).to eql(app_binding.last_operation.updated_at)
          end
        end
      end
    end
  end
end
