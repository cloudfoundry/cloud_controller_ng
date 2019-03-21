require 'spec_helper'
require 'cloud_controller/validate_database_keys'

module VCAP::CloudController
  RSpec.describe ValidateDatabaseKeys do
    describe '.validate!' do
      let(:config) { Config.new({}) }

      it 'calls .can_decrypt_all_rows! and .validate_encryption_key_values_unchanged! in the correct order' do
        expect(ValidateDatabaseKeys).to receive(:can_decrypt_all_rows!).with(config).ordered
        expect(ValidateDatabaseKeys).to receive(:validate_encryption_key_values_unchanged!).with(config).ordered
        ValidateDatabaseKeys.validate!(config)
      end
    end

    describe '.can_decrypt_all_rows!' do
      let(:space) { Space.first }
      let(:historical_app) { AppModel.make(space: space) }
      let(:app1) { AppModel.make }
      let(:app2) { AppModel.make }
      let(:app3) { AppModel.make }
      let(:service_instance) { ServiceInstance.make(space: space) }
      let(:service_binding) { ServiceBinding.make(service_instance: service_instance, app: historical_app) }
      let(:label1) { 'encryption_key_label_1' }
      let(:label2) { 'encryption_key_label_2' }
      let(:label3) { 'encryption_key_label_3' }
      let(:env_vars) { { 'environment' => 'vars' } }

      let(:config) { Config.new({}) }
      let(:initial_db_encryption_part) do { db_encryption_key: 'something' } end
      let(:next_db_encryption_part) do {
        database_encryption: { keys:
          {
            label1.to_sym => 'secret_key1',
            label2.to_sym => 'secret_key_2',
            label3.to_sym => 'secret_key_3',
          },
                               current_key_label: label2,
        }
      }
      end

      before do
        allow(Encryptor).to receive(:encrypted_classes).and_return([
          'VCAP::CloudController::ServiceBinding',
          'VCAP::CloudController::AppModel',
          'VCAP::CloudController::ServiceInstance',])
      end

      context 'when no encryption keys are specified' do
        let(:config) { Config.new({}) }

        it 'raises an error' do
          expect {
            ValidateDatabaseKeys.can_decrypt_all_rows!(config)
          }.to raise_error(ValidateDatabaseKeys::DatabaseEncryptionKeyMissingError, /No database encryption keys are specified/)
        end
      end

      context 'when all rows have blank encryption_key_labels' do
        before do
          app1.update(encryption_key_label: nil)
          app2.update(encryption_key_label: '')
          app3.update(encryption_key_label: nil)
          historical_app.update(encryption_key_label: nil)
          service_binding.update(encryption_key_label: '')
          service_instance.update(encryption_key_label: nil)
        end

        context 'when both the db_encryption_key and custom encryption_keys are present' do
          let(:config) { Config.new(initial_db_encryption_part.merge(next_db_encryption_part)) }
          it 'can decrypt all the rows' do
            expect {
              ValidateDatabaseKeys.can_decrypt_all_rows!(config)
            }.not_to raise_error
          end
        end

        context 'when only the db_encryption_key is present' do
          let(:config) { Config.new(initial_db_encryption_part) }

          it 'can decrypt all the rows' do
            expect {
              ValidateDatabaseKeys.can_decrypt_all_rows!(config)
            }.not_to raise_error
          end
        end

        context 'when only the database_encryption part is present' do
          let(:config) { Config.new(next_db_encryption_part) }

          it 'cannot decrypt some of the rows' do
            expect {
              ValidateDatabaseKeys.can_decrypt_all_rows!(config)
            }.to raise_error(ValidateDatabaseKeys::DatabaseEncryptionKeyMissingError,
              /Encryption key from 'cc.db_encryption_key'/)
          end
        end
      end

      context 'when all rows have a non-nil encryption_key_label' do
        before do
          app1.update(encryption_key_label: label1)
          app2.update(encryption_key_label: label2)
          app3.update(encryption_key_label: label3)
          historical_app.update(encryption_key_label: label3)
          service_binding.update(encryption_key_label: label1)
          service_instance.update(encryption_key_label: label3)
        end

        context 'when both the db_encryption_key and custom encryption_keys are present' do
          let(:config) { Config.new(initial_db_encryption_part.merge(next_db_encryption_part)) }
          it 'can decrypt all the rows' do
            expect {
              ValidateDatabaseKeys.can_decrypt_all_rows!(config)
            }.not_to raise_error
          end
        end

        context 'when only the db_encryption_key is present' do
          let(:config) { Config.new(initial_db_encryption_part) }

          it 'cannot decrypt all the rows' do
            expect {
              ValidateDatabaseKeys.can_decrypt_all_rows!(config)
            }.to raise_error(ValidateDatabaseKeys::DatabaseEncryptionKeyMissingError,
              /Encryption key\(s\) '#{label1}', '#{label2}', '#{label3}' are still in use but not present in 'cc.database_encryption.keys'/)
          end
        end

        context 'when only the database_encryption part is present' do
          let(:config) { Config.new(next_db_encryption_part) }
          it 'can decrypt all the rows' do
            expect {
              ValidateDatabaseKeys.can_decrypt_all_rows!(config)
            }.not_to raise_error
          end
        end
      end

      context 'when some rows are encrypted with "db_encryption_key" and others with custom keys' do
        before do
          app1.update(encryption_key_label: label1)
          app2.update(encryption_key_label: label2)
          app3.update(encryption_key_label: label3)
          historical_app.update(encryption_key_label: '')
          service_binding.update(encryption_key_label: nil)
          service_instance.update(encryption_key_label: '')
        end

        context 'when both the db_encryption_key and all custom encryption_keys are present' do
          let(:config) { Config.new(initial_db_encryption_part.merge(next_db_encryption_part)) }
          it 'can decrypt all the rows' do
            expect {
              ValidateDatabaseKeys.can_decrypt_all_rows!(config)
            }.not_to raise_error
          end
        end

        context 'when only the db_encryption_key is present' do
          let(:config) { Config.new(initial_db_encryption_part) }

          it 'cannot decrypt all the rows' do
            expect {
              ValidateDatabaseKeys.can_decrypt_all_rows!(config)
            }.to raise_error(ValidateDatabaseKeys::DatabaseEncryptionKeyMissingError,
              /Encryption key\(s\) '#{label1}', '#{label2}', '#{label3}' are still in use but not present in 'cc.database_encryption.keys'/)
          end
        end

        context 'when only the database_encryption part is present' do
          let(:config) { Config.new(next_db_encryption_part) }

          it 'cannot decrypt all the rows' do
            expect {
              ValidateDatabaseKeys.can_decrypt_all_rows!(config)
            }.to raise_error(ValidateDatabaseKeys::DatabaseEncryptionKeyMissingError,
              /Encryption key from 'cc.db_encryption_key'/)
          end
        end

        context 'when only some of the database_encryption labels are present' do
          let(:next_db_encryption_part) do {
            database_encryption: { keys:
              {
                label1.to_sym => 'secret_key1',
                label2.to_sym => 'secret_key_2',
              },
                                   current_key_label: label2,
            }
          }
          end
          let(:config) { Config.new(next_db_encryption_part) }

          it 'cannot decrypt all the rows' do
            expect {
              ValidateDatabaseKeys.can_decrypt_all_rows!(config)
            }.to raise_error(ValidateDatabaseKeys::DatabaseEncryptionKeyMissingError,
              /Encryption key from 'cc.db_encryption_key'.*Encryption key\(s\) '#{label3}' are still in use but not present in 'cc.database_encryption.keys'/m)
          end
        end
      end
    end

    describe '.validate_encryption_key_values_unchanged!' do
      let(:label1) { 'encryption_key_label_1' }
      let(:label2) { 'encryption_key_label_2' }
      let(:label3) { 'encryption_key_label_3' }
      let(:label1_sentinel) { 'sentinel_1' }
      let(:label2_sentinel) { 'sentinel_2' }
      let(:label3_sentinel) { 'sentinel_3' }
      let(:label1_secret_key) { 'secret_key_1' }
      let(:label2_secret_key) { 'secret_key_2' }
      let(:label3_secret_key) { 'secret_key_3' }
      let(:morton_salt) { Encryptor.generate_salt }
      let(:label1_encrypted_value) { Encryptor.encrypt_raw(label1_sentinel, label1_secret_key, morton_salt) }
      let(:label2_encrypted_value) { Encryptor.encrypt_raw(label2_sentinel, label2_secret_key, morton_salt) }
      let(:label3_encrypted_value) { Encryptor.encrypt_raw(label3_sentinel, label3_secret_key, morton_salt) }

      let(:config) { Config.new(database_encryption_keys_config) }
      let(:database_encryption_keys_config) do {
        database_encryption: { keys:
          {
            label1.to_sym => label1_secret_key,
            label2.to_sym => label2_secret_key,
            label3.to_sym => label3_secret_key,
          },
                               current_key_label: label2,
        }
      }
      end

      context 'when every key in the config can decrypt a sentinel value' do
        before do
          EncryptionKeySentinelModel.create(
            expected_value: label1_sentinel,
            encrypted_value: label1_encrypted_value,
            encryption_key_label: label1,
            salt: morton_salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS,
          )
          EncryptionKeySentinelModel.create(
            expected_value: label2_sentinel,
            encrypted_value: label2_encrypted_value,
            encryption_key_label: label2,
            salt: morton_salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS,
          )
          EncryptionKeySentinelModel.create(
            expected_value: label3_sentinel,
            encrypted_value: label3_encrypted_value,
            encryption_key_label: label3,
            salt: morton_salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS,
          )
        end

        it 'does not raise an error' do
          expect {
            ValidateDatabaseKeys.validate_encryption_key_values_unchanged!(config)
          }.not_to raise_error
        end
      end

      context 'when some keys in the config incorrectly decrypt a sentinel value' do
        let(:changed_encryption_key) { 'bogus-changed-key' }
        let(:changed_encryption_key2) { 'bogus-changed-key2' }
        let(:database_encryption_keys_config) do
          {
            database_encryption: {
              keys: {
                label1.to_sym => changed_encryption_key,
                label2.to_sym => changed_encryption_key2,
                label3.to_sym => label3_secret_key,
              },
              current_key_label: label2,
            }
          }
        end

        before do
          EncryptionKeySentinelModel.create(
            expected_value: label1_sentinel,
            encrypted_value: label1_encrypted_value,
            encryption_key_label: label1,
            salt: morton_salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS,
          )
          EncryptionKeySentinelModel.create(
            expected_value: label2_sentinel,
            encrypted_value: label2_encrypted_value,
            encryption_key_label: label2,
            salt: morton_salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS,
          )
          EncryptionKeySentinelModel.create(
            expected_value: label3_sentinel,
            encrypted_value: label3_encrypted_value,
            encryption_key_label: label3,
            salt: morton_salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS,
          )
        end

        context 'when the expected value does not match the decrypted value' do
          before do
            allow(Encryptor).to receive(:decrypt_raw).and_call_original
            allow(Encryptor).to receive(:decrypt_raw).with(
              label1_encrypted_value,
              changed_encryption_key,
              morton_salt,
              iterations: Encryptor::ENCRYPTION_ITERATIONS
            ).and_return('gibberish')
            allow(Encryptor).to receive(:decrypt_raw).with(label2_encrypted_value,
              changed_encryption_key2,
              morton_salt,
              iterations: Encryptor::ENCRYPTION_ITERATIONS
            ).and_return('gibberish2')
          end

          it 'raises an EncryptionKeySentinelDecryptionMismatchError' do
            expected_message = "Encryption key(s) '#{label1}', '#{label2}' have had their values changed. " \
                               'Label and value pairs should not change, rather a new label and value pair should be added. ' \
                               'See https://docs.cloudfoundry.org/adminguide/encrypting-cc-db.html for more information.'
            expect {
              ValidateDatabaseKeys.validate_encryption_key_values_unchanged!(config)
            }.to raise_error(ValidateDatabaseKeys::EncryptionKeySentinelDecryptionMismatchError, expected_message)
          end
        end

        context 'when a bad decrypt error is raised' do
          let(:morton_salt) { 'HelloEli' }

          it 'raises an EncryptionKeySentinelDecryptionMismatchError' do
            expected_message = "Encryption key(s) '#{label1}', '#{label2}' have had their values changed. " \
                             'Label and value pairs should not change, rather a new label and value pair should be added. ' \
                             'See https://docs.cloudfoundry.org/adminguide/encrypting-cc-db.html for more information.'
            expect {
              ValidateDatabaseKeys.validate_encryption_key_values_unchanged!(config)
            }.to raise_error(ValidateDatabaseKeys::EncryptionKeySentinelDecryptionMismatchError, expected_message)
          end
        end
      end

      context 'pruning deleted keys' do
        let(:database_encryption_keys_config) do {
            database_encryption: { keys:
                                       {
                                           label2.to_sym => label2_secret_key,
                                           label3.to_sym => label3_secret_key,
                                       },
                                   current_key_label: label2,
            }
        }
        end

        before do
          # Delete seeded sentinels
          EncryptionKeySentinelModel.dataset.destroy

          EncryptionKeySentinelModel.create(
            expected_value: label1_sentinel,
            encrypted_value: label1_encrypted_value,
            encryption_key_label: label1,
            salt: morton_salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS,
          )
          EncryptionKeySentinelModel.create(
            expected_value: label1_sentinel,
            encrypted_value: label1_encrypted_value,
            encryption_key_label: 'another-extra-label',
            salt: morton_salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS,
          )

          EncryptionKeySentinelModel.create(
            expected_value: label2_sentinel,
            encrypted_value: label2_encrypted_value,
            encryption_key_label: label2,
            salt: morton_salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS,
          )
          EncryptionKeySentinelModel.create(
            expected_value: label3_sentinel,
            encrypted_value: label3_encrypted_value,
            encryption_key_label: label3,
            salt: morton_salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS,
          )
        end

        it 'trims sentinel values belonging to keys that no longer exist in the config' do
          expect(EncryptionKeySentinelModel.count).to eq(4)
          ValidateDatabaseKeys.validate_encryption_key_values_unchanged!(config)
          expect(EncryptionKeySentinelModel.find(encryption_key_label: label1)).to be_nil
          expect(EncryptionKeySentinelModel.find(encryption_key_label: 'another-extra-label')).to be_nil

          expect(EncryptionKeySentinelModel.count).to eq(2)
          expect(EncryptionKeySentinelModel.find(encryption_key_label: label2)).to be_present
          expect(EncryptionKeySentinelModel.find(encryption_key_label: label3)).to be_present
        end
      end
    end
  end
end
