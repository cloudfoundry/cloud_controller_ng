require 'spec_helper'
require 'cloud_controller/validate_database_keys'

module VCAP::CloudController
  RSpec.describe ValidateDatabaseKeys do
    describe '#validate!' do
      # Apps have encrypted env vars
      let(:historical_app) { AppModel.make }
      let(:env_vars) { { 'environment' => 'vars' } }

      before do
        allow(Encryptor).to receive(:encrypted_classes).and_return([
          'VCAP::CloudController::AppModel',
        ])
      end

      after do
        Encryptor.db_encryption_key = nil
        Encryptor.database_encryption_keys = nil
        Encryptor.current_encryption_key_label = nil
      end

      describe 'when there is a data using the db_encryption_key' do
        before do
          # These apps' encryption_key_labels will be NULL
          historical_app.environment_variables = env_vars
          historical_app.save
        end

        context 'when the db_encryption_key is still present' do
          let(:config) { Config.new(db_encryption_key: 'something') }
          it 'does not raise' do
            expect do
              ValidateDatabaseKeys.validate!(config)
            end.not_to raise_error
          end
        end

        context 'when the db_encryption_key has been removed' do
          let(:config) { Config.new({}) }

          it 'raises' do
            expect do
              ValidateDatabaseKeys.validate!(config)
            end.to raise_error(ValidateDatabaseKeys::DbEncryptionKeyMissingError)
          end
        end
      end
      describe 'when there are not records encrypted with `db_encryption_key`' do
        before do
          Encryptor.database_encryption_keys = {
            alpha: 'a',
            bravo: 'b',
          }
          Encryptor.current_encryption_key_label = :alpha

          historical_app.environment_variables = env_vars
          historical_app.save

          expect(AppModel.where(encryption_key_label: nil).count).to eq 0
        end

        context 'when the db_encryption_key is still present' do
          let(:config) { Config.new(db_encryption_key: 'something') }
          it 'does not raise' do
            expect do
              ValidateDatabaseKeys.validate!(config)
            end.not_to raise_error
          end
        end

        context 'when the db_encryption_key has been removed' do
          let(:config) { Config.new({}) }

          it 'raises' do
            expect do
              ValidateDatabaseKeys.validate!(config)
            end.not_to raise_error
          end
        end
      end
    end
  end
end
