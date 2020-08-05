require 'spec_helper'
require 'fetchers/service_credential_binding_list_fetcher'

module VCAP
  module CloudController
    RSpec.describe ServiceCredentialBindingListFetcher do
      let(:fetcher) { ServiceCredentialBindingListFetcher.new }

      describe 'no bindings' do
        it 'returns an empty result' do
          expect(fetcher.fetch(space_guids: :all).all).to eql([])
        end
      end

      describe 'app and key bindings' do
        let(:space) { VCAP::CloudController::Space.make }
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
        let!(:key_binding) { VCAP::CloudController::ServiceKey.make(service_instance: instance) }
        let!(:app_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: instance) }

        context 'when getting everything' do
          it 'returns both key and app bindings' do
            bindings = fetcher.fetch(space_guids: :all).all
            binding_guids = bindings.map(&:guid)

            expect(binding_guids).to contain_exactly(key_binding.guid, app_binding.guid)
          end
        end

        context 'when limiting to a space' do
          let(:other_space) { VCAP::CloudController::Space.make }
          let(:other_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: other_space) }
          let!(:key_other_binding) { VCAP::CloudController::ServiceKey.make(service_instance: other_instance) }
          let!(:app_other_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: other_instance) }

          it 'returns only the bindings within that space' do
            bindings = fetcher.fetch(space_guids: [space.guid]).all
            binding_guids = bindings.map(&:guid)

            expect(binding_guids).to contain_exactly(key_binding.guid, app_binding.guid)
          end
        end
      end

      describe 'fetching app bindings' do
        let!(:app_binding) { VCAP::CloudController::ServiceBinding.make }

        it 'allows the last operation to be accessed' do
          app_binding.save_with_new_operation(
            {
              type: 'create',
              state: 'succeeded',
              description: 'some description'
            }
          )

          credential_binding = fetcher.fetch(space_guids: :all).first
          last_operation = credential_binding.last_operation

          expect(last_operation).to be_present

          expect(last_operation.type).to eql 'create'
          expect(last_operation.state).to eql 'succeeded'
          expect(last_operation.description).to eql 'some description'
          expect(last_operation.created_at).to be_present
          expect(last_operation.updated_at).to be_present
        end
      end
    end
  end
end
