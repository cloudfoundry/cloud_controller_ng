require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RotateDatabaseKey do
    describe '#perform' do
      let(:app) { AppModel.make }
      let(:app_new_key_label) { AppModel.make }
      let(:env_vars) { { 'environment' => 'vars' } }
      let(:env_vars_2) { { 'vars' => 'environment' } }

      let(:service_binding) { ServiceBinding.make }
      let(:service_binding_new_key_label) { ServiceBinding.make }
      let(:credentials) { { 'secret' => 'creds' } }
      let(:credentials_2) { { 'more' => 'secrets' } }
      let(:volume_mounts) { { 'volume' => 'mount' } }
      let(:volume_mounts_2) { { 'mount' => 'vesuvius' } }
      let(:database_encryption_keys) { { 'old' => 'old-key', 'new' => 'new-key' } }

      before do
        allow(Encryptor).to receive(:current_encryption_key_label) { 'old' }
        allow(Encryptor).to receive(:database_encryption_keys) { database_encryption_keys }

        app.environment_variables = env_vars
        app.save

        service_binding.credentials = credentials
        service_binding.volume_mounts = volume_mounts
        service_binding.save

        allow(Encryptor).to receive(:current_encryption_key_label) { 'new' }

        app_new_key_label.environment_variables = env_vars_2
        app_new_key_label.save

        service_binding_new_key_label.credentials = credentials_2
        service_binding_new_key_label.volume_mounts = volume_mounts_2
        service_binding_new_key_label.save

        allow(VCAP::CloudController::Encryptor).to receive(:encrypt).and_call_original
        allow(VCAP::CloudController::Encryptor).to receive(:decrypt).and_call_original
        allow(VCAP::CloudController::Encryptor).to receive(:encrypted_classes).and_return(['VCAP::CloudController::ServiceBinding', 'VCAP::CloudController::AppModel'])
      end

      it 'changes the key label of each model' do
        expect(app.encryption_key_label).to eq('old')
        expect(service_binding.encryption_key_label).to eq('old')

        RotateDatabaseKey.perform

        expect(app.reload.encryption_key_label).to eq('new')
        expect(service_binding.reload.encryption_key_label).to eq('new')
      end

      it 're-encrypts all encrypted fields with the new key for all rows' do
        expect(VCAP::CloudController::Encryptor).to receive(:encrypt).
          with(JSON.dump(env_vars), app.salt).exactly(:twice)

        expect(VCAP::CloudController::Encryptor).to receive(:encrypt).
          with(JSON.dump(credentials), service_binding.salt).exactly(:twice)

        expect(VCAP::CloudController::Encryptor).to receive(:encrypt).
          with(JSON.dump(volume_mounts), service_binding.volume_mounts_salt).exactly(:twice)

        RotateDatabaseKey.perform
      end

      it 'does not change the decrypted value' do
        RotateDatabaseKey.perform

        expect(app.environment_variables).to eq(env_vars)
        expect(service_binding.credentials).to eq(credentials)
        expect(service_binding.volume_mounts).to eq(volume_mounts)
      end

      it 'does not re-encrypt values that are already encrypted with the new label' do
        expect(VCAP::CloudController::Encryptor).not_to receive(:encrypt).
          with(JSON.dump(env_vars_2), app_new_key_label.salt)

        expect(VCAP::CloudController::Encryptor).not_to receive(:encrypt).
          with(JSON.dump(credentials_2), service_binding_new_key_label.salt)

        expect(VCAP::CloudController::Encryptor).not_to receive(:encrypt).
          with(JSON.dump(volume_mounts_2), service_binding_new_key_label.volume_mounts_salt)

        RotateDatabaseKey.perform
      end
    end
  end
end
