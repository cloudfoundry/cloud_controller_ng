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
          let!(:app_binding) { ServiceBinding.make(service_instance: service_instance) }

          it 'can be found' do
            credential_binding = fetcher.fetch(app_binding.guid, space_guids: [space.guid])

            expect(credential_binding).not_to be_nil
            expect(credential_binding.type).to eql(type)
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
          let!(:app_binding) { ServiceBinding.make(service_instance: service_instance) }

          it 'can be found' do
            credential_binding = fetcher.fetch(app_binding.guid, space_guids: [space.guid])

            expect(credential_binding).not_to be_nil
            expect(credential_binding.type).to eql(type)
          end

          describe 'when not in the space' do
            let!(:other_space) { Space.make }
            it 'can not be found' do
              credential_binding = fetcher.fetch(app_binding.guid, space_guids: [other_space.guid])

              expect(credential_binding).to be_nil
            end
          end
        end
      end
    end
  end
end
