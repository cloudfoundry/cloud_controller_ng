require 'spec_helper'
require 'service_credential_binding_delete'

module VCAP::CloudController
  RSpec.describe V3::ServiceCredentialBindingDelete do
    let(:subject) { described_class.new }
    let(:binding) { ServiceBinding.make(service_instance: UserProvidedServiceInstance.make) }

    it 'can delete the credential binding' do
      subject.delete(binding)

      expect {
        binding.reload
      }.to raise_error(Sequel::Error, 'Record not found')
    end

    context 'when the service instance is a managed service' do
      let(:binding) { ServiceBinding.make(service_instance: ManagedServiceInstance.make) }
      it 'raises an error' do
        expect {
          subject.delete(binding)
        }.to raise_error(V3::ServiceCredentialBindingDelete::NotImplementedError)
      end
    end
  end
end
