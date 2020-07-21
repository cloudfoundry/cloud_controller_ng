require 'spec_helper'

module VCAP
  module CloudController
    RSpec.describe ServiceCredentialBinding, type: :model do
      describe 'not a real guid' do
        it 'should return nothing' do
          credential_binding = ServiceCredentialBinding.first(guid: 'does-not-exist')
          expect(credential_binding).to be_nil
        end
      end

      describe 'service keys' do
        let(:service_instance) { ManagedServiceInstance.make }
        let!(:service_key) { ServiceKey.make(service_instance: service_instance) }

        it 'can be found' do
          credential_binding = ServiceCredentialBinding.first(guid: service_key.guid)
          expect(credential_binding).not_to be_nil
        end

        it 'can access the service instance' do
          credential_binding = ServiceCredentialBinding.first(guid: service_key.guid)
          expect(credential_binding.service_instance).to eql(service_instance)
        end
      end

      describe 'app bindings' do
        let(:service_instance) { ManagedServiceInstance.make }
        let!(:app_binding) { ServiceBinding.make(service_instance: service_instance) }

        it 'can be found' do
          credential_binding = ServiceCredentialBinding.first(guid: app_binding.guid)
          expect(credential_binding).not_to be_nil
        end

        it 'can access the service instance' do
          credential_binding = ServiceCredentialBinding.first(guid: app_binding.guid)
          expect(credential_binding.service_instance).to eql(service_instance)
        end
      end
    end
  end
end
