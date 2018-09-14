require 'spec_helper'
require 'cloud_controller/validate_database_keys'

module VCAP::CloudController
  RSpec.describe ValidateDatabaseKeys do
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
            ValidateDatabaseKeys. can_decrypt_all_rows!(config)
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
  end
end
