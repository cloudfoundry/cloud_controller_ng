require 'spec_helper'

module VCAP::CloudController
  RSpec.describe CredhubCredentialPopulator do
    describe '#transform' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:instance)  { ManagedServiceInstance.make(space: space) }
      let(:service_keys) { [
        ServiceKey.make(:credhub_reference, name: 'credhub-key-1', service_instance: instance),
        ServiceKey.make(name: 'non-credhub-key-1', service_instance: instance, credentials: non_credhub_creds),
        ServiceKey.make(:credhub_reference, name: 'credhub-key-2', service_instance: instance)
      ]
      }
      let(:credhub_cred_1) { { 'username' => 'user' } }
      let(:credhub_cred_2) { { 'hello' => 'there' } }
      let(:non_credhub_creds) { { 'hello' => 'there' } }
      let(:fake_credhub_client) { instance_double(Credhub::Client) }

      subject { CredhubCredentialPopulator.new(fake_credhub_client) }

      before do
        allow(fake_credhub_client).to receive(:get_credential_by_name).with(service_keys[0].credhub_reference).and_return(credhub_cred_1)
        allow(fake_credhub_client).to receive(:get_credential_by_name).with(service_keys[2].credhub_reference).and_return(credhub_cred_2)
      end

      it 'fills in any credhub credentials with their values from CredHub' do
        transformed_keys = subject.transform(service_keys)
        credhub_key_1 = transformed_keys.find { |key| key.name == 'credhub-key-1' }
        expect(credhub_key_1.credentials).to eq(credhub_cred_1)

        credhub_key_2 = transformed_keys.find { |key| key.name == 'credhub-key-2' }
        expect(credhub_key_2.credentials).to eq(credhub_cred_2)

        non_credhub_key = transformed_keys.find { |key| key.name == 'non-credhub-key-1' }
        expect(non_credhub_key.credentials).to eq(non_credhub_creds)
      end
    end
  end
end
