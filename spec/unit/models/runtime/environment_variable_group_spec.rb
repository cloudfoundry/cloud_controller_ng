require 'spec_helper'

module VCAP::CloudController
  RSpec.describe EnvironmentVariableGroup, type: :model do
    subject(:env_group) { EnvironmentVariableGroup.make }

    it { is_expected.to have_timestamp_columns }

    it_behaves_like 'a model with an encrypted attribute' do
      let(:encrypted_attr) { :environment_json }
      let(:attr_salt) { :salt }
      let(:value_to_encrypt) { { 'SUPER' => 'SECRET' } }
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :environment_json }
      it { is_expected.to import_attributes :environment_json }
    end

    describe '#staging' do
      context 'when the corresponding db object does not exist' do
        before do
          EnvironmentVariableGroup.dataset.destroy
        end

        it 'creates a new database object with the right name' do
          expect(EnvironmentVariableGroup).to receive(:create).with(name: 'staging')
          EnvironmentVariableGroup.staging
        end

        it 'initializes the object with an empty environment' do
          expect(EnvironmentVariableGroup.staging.environment_json).to eq({})
        end

        it 'updates the object on save' do
          staging = EnvironmentVariableGroup.staging
          staging.environment_json = { 'abc' => 'easy as 123' }
          staging.save

          expect(EnvironmentVariableGroup.staging.environment_json).to eq({ 'abc' => 'easy as 123' })
        end
      end

      context 'when the corresponding db object exists' do
        before do
          staging_group = EnvironmentVariableGroup.find(name: 'staging')
          staging_group.environment_json = { 'abc' => 123 }
          staging_group.save
        end

        it 'returns the existing object' do
          expect(EnvironmentVariableGroup.staging.environment_json).to eq('abc' => 123)
        end
      end
    end

    describe '#running' do
      context 'when the corresponding db object does not exist' do
        before do
          EnvironmentVariableGroup.dataset.destroy
        end

        it 'creates a new database object with the right name' do
          expect(EnvironmentVariableGroup).to receive(:create).with(name: 'running')
          EnvironmentVariableGroup.running
        end

        it 'initializes the object with an empty environment' do
          expect(EnvironmentVariableGroup.running.environment_json).to eq({})
        end

        it 'updates the object on save' do
          running = EnvironmentVariableGroup.running
          running.environment_json = { 'abc' => 'easy as 123' }
          running.save

          expect(EnvironmentVariableGroup.running.environment_json).to eq({ 'abc' => 'easy as 123' })
        end
      end

      context 'when the corresponding db object exists' do
        before do
          running_group = EnvironmentVariableGroup.find(name: 'running')
          running_group.environment_json = { 'abc' => 123 }
          running_group.save
        end

        it 'returns the existing object' do
          expect(EnvironmentVariableGroup.running.environment_json).to eq('abc' => 123)
        end
      end
    end

    describe '#validate' do
      describe 'environment_variables' do
        it 'validates them' do
          expect {
            EnvironmentVariableGroup.make(environment_json: { 'VCAP_SERVICES' => {} })
          }.to raise_error(Sequel::ValidationFailed, /cannot start with VCAP_/)
        end
      end
    end

    describe 'environment_json encryption' do
      let(:long_env) { { 'many_os' => 'o' * 10_000 } }

      it 'works with long serialized environments' do
        var_group = EnvironmentVariableGroup.make(environment_json: long_env)
        var_group.reload
        expect(var_group.environment_json).to eq(long_env)
      end

      describe 'changing iteration count' do
        it 'does not update the encryption_iterations field until after decrypting existing data' do
          allow(Encryptor).to receive(:pbkdf2_hmac_iterations).and_return(2048)
          var_group = EnvironmentVariableGroup.make(environment_json: { 'name' => 'value' })

          allow(Encryptor).to receive(:pbkdf2_hmac_iterations).and_return(12345)
          var_group.update(environment_json: { 'name' => 'new_value' })

          expect(var_group.environment_json).to eq({ 'name' => 'new_value' })
          expect(var_group.encryption_iterations).to eq 12345
        end
      end
    end
  end
end
