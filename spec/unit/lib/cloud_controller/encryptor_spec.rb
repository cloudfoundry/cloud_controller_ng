require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Encryptor do
    let(:salt) { Encryptor.generate_salt }

    describe 'generating some salt' do
      it 'returns a short, random string' do
        expect(salt.length).to eql(16)
        expect(salt).not_to eql(Encryptor.generate_salt)
      end
    end

    describe 'encrypting a string' do
      let(:input) { 'i-am-the-input' }
      let!(:encrypted_string) { Encryptor.encrypt(input, salt) }

      it 'returns an encrypted string' do
        expect(encrypted_string).to match(/\w+/)
        expect(encrypted_string).not_to include(input)
      end

      it 'is deterministic' do
        expect(Encryptor.encrypt(input, salt)).to eql(encrypted_string)
      end

      it 'depends on the salt' do
        expect(Encryptor.encrypt(input, Encryptor.generate_salt)).not_to eql(encrypted_string)
      end

      it 'depends on the db_encryption_key from the CC config file' do
        allow(VCAP::CloudController::Encryptor).to receive(:db_encryption_key).and_return('a-totally-different-key')
        expect(Encryptor.encrypt(input, salt)).not_to eql(encrypted_string)
      end

      it 'does not encrypt null values' do
        expect(Encryptor.encrypt(nil, salt)).to be_nil
      end

      context 'when database_encryption_keys has been set' do
        let(:salt) { 'FFFFFFFFFFFFFFFF' }
        let(:encrypted_death_string) { 'NHQ+mjls1UHJBqpO0KWjTA==' }
        let(:encrypted_legacy_string) { '1XJDJYNqWOKokyVx0WHZ/g==' }

        before(:each) do
          Encryptor.db_encryption_key = 'legacy-crypto-key'
          Encryptor.database_encryption_keys = {
            'foo' => 'fooencryptionkey',
            'death' => 'headbangingdeathmetalkey'
          }
        end

        context 'when the label is found in the hash' do
          it 'will encrypt using the value corresponding to the label' do
            allow(Encryptor).to receive(:current_encryption_key_label) { 'death' }
            expect(Encryptor.encrypt(input, salt)).to eql(encrypted_death_string)
          end
        end

        context 'when the label is not found in the hash' do
          it 'will encrypt using current db_encryption_key when the label is not nil' do
            allow(Encryptor).to receive(:current_encryption_key_label) { 'Inigo Montoya' }
            expect(Encryptor.encrypt(input, salt)).to eql(encrypted_legacy_string)
          end

          it 'will encrypt using current db_encryption_key when the label is nil' do
            allow(Encryptor).to receive(:current_encryption_key_label) { nil }
            expect(Encryptor.encrypt(input, salt)).to eql(encrypted_legacy_string)
          end
        end
      end

      context 'when database_encryption_keys has not been set' do
        let(:salt) { 'FFFFFFFFFFFFFFFF' }
        let(:encrypted_legacy_string) { '1XJDJYNqWOKokyVx0WHZ/g==' }

        before(:each) do
          Encryptor.db_encryption_key = 'legacy-crypto-key'
          Encryptor.database_encryption_keys = nil
          allow(Encryptor).to receive(:current_encryption_key_label) { 'foo' }
        end

        it 'will encrypt using db_encryption_key' do
          expect(Encryptor.encrypt(input, salt)).to eql(encrypted_legacy_string)
        end
      end
    end

    describe '#decrypt' do
      let(:unencrypted_string) { 'some-string' }

      before(:each) do
        Encryptor.db_encryption_key = 'legacy-crypto-key'
      end

      it 'returns the original string' do
        encrypted_string = Encryptor.encrypt(unencrypted_string, salt)
        expect(Encryptor.decrypt(encrypted_string, salt)).to eq(unencrypted_string)
      end

      it 'returns nil if the encrypted string is nil' do
        expect(Encryptor.decrypt(nil, salt)).to be_nil
      end

      context 'when database_encryption_keys is configured' do
        before(:each) do
          allow(Encryptor).to receive(:current_encryption_key_label) { 'foo' }
          Encryptor.database_encryption_keys = {
            'foo' => 'fooencryptionkey',
            'death' => 'headbangingdeathmetalkey'
          }
        end

        context 'when no encryption key label is passed' do
          before(:each) do
            allow(Encryptor).to receive(:current_encryption_key_label) { nil }
          end

          it 'decrypts using #db_encryption_key' do
            encrypted_string = Encryptor.encrypt(unencrypted_string, salt)
            expect(Encryptor).to receive(:db_encryption_key).and_call_original.at_least(:once)
            expect(Encryptor.decrypt(encrypted_string, salt)).to eq(unencrypted_string)
          end
        end

        context 'when encryption was done using a labelled key' do
          context 'when no key label is passed for decryption' do
            it 'fails to decrypt' do
              encrypted_string = Encryptor.encrypt(unencrypted_string, salt)
              expect { Encryptor.decrypt(encrypted_string, salt) }.to raise_error(/bad decrypt/)
            end
          end

          context 'when the wrong label is passed for decryption' do
            before(:each) do
              allow(Encryptor).to receive(:current_encryption_key_label) { 'foo' }
            end
            it 'fails to decrypt' do
              encrypted_string = Encryptor.encrypt(unencrypted_string, salt)
              expect { Encryptor.decrypt(encrypted_string, salt, 'death') }.to raise_error(/bad decrypt/)
            end
          end

          it 'decrypts using the key specified by the passed label' do
            encrypted_string = Encryptor.encrypt(unencrypted_string, salt)
            expect(Encryptor.decrypt(encrypted_string, salt, 'foo')).to eq(unencrypted_string)
          end
        end
      end

      context 'when the salt is only 8 bytes (legacy mode)' do
        let(:salt) { SecureRandom.hex(4).to_s }

        it 'decrypts correctly' do
          encrypted_string = Encryptor.encrypt(unencrypted_string, salt)
          expect(Encryptor.decrypt(encrypted_string, salt)).to eq(unencrypted_string)
        end
      end
    end
  end

  RSpec.describe Encryptor::FieldEncryptor do
    let(:klass) do
      Class.new do
        include VCAP::CloudController::Encryptor::FieldEncryptor
      end
    end

    let(:db) { double(Sequel::Database) }

    before do
      allow(klass).to receive(:columns) { columns }
      allow(db).to receive(:transaction) do |&block|
        block.call
      end
      klass.send :attr_accessor, *columns # emulate Sequel super methods
    end

    describe '#set_field_as_encrypted' do
      context 'model does not have the salt column' do
        let(:columns) { [:id, :name, :size, :encryption_key_label] }

        context 'default name' do
          it 'raises an error' do
            expect {
              klass.send :set_field_as_encrypted, :name
            }.to raise_error(RuntimeError, /salt/)
          end
        end

        context 'explicit name' do
          it 'raises an error' do
            expect {
              klass.send :set_field_as_encrypted, :name, salt: :foobar
            }.to raise_error(RuntimeError, /foobar/)
          end
        end
      end

      context 'model has the salt column' do
        let(:columns) { [:id, :name, :size, :salt, :encryption_key_label] }

        it 'does not raise an error' do
          expect {
            klass.send :set_field_as_encrypted, :name
          }.to_not raise_error
        end

        it 'creates a salt generation method' do
          klass.send :set_field_as_encrypted, :name
          expect(klass.instance_methods).to include(:generate_salt)
        end

        context 'explicit name' do
          let(:columns) { [:id, :name, :size, :foobar, :encryption_key_label] }

          it 'does not raise an error' do
            expect {
              klass.send :set_field_as_encrypted, :name, salt: :foobar
            }.to_not raise_error
          end

          it 'creates a salt generation method' do
            klass.send :set_field_as_encrypted, :name, salt: :foobar
            expect(klass.instance_methods).to include(:generate_foobar)
          end
        end
      end

      context 'model does not have the "encryption_key_label" column' do
        let(:columns) { [:id, :name, :salt, :size] }

        it 'raises an error' do
          expect {
            klass.send :set_field_as_encrypted, :name
          }.to raise_error(RuntimeError, /encryption_key_label/)
        end
      end
    end

    describe 'field-specific methods' do
      let(:columns) { [:sekret, :salt, :encryption_key_label] }
      let(:klass2) { Class.new klass }
      let(:subject) { klass2.new }
      let(:encryption_args) { {} }
      let(:default_key) { 'somerandomkey' }

      before do
        allow(subject).to receive(:db) { db }
        klass.class_eval do
          def underlying_sekret=(value)
            @sekret = value
          end

          def underlying_sekret
            @sekret
          end
        end
        klass2.send :set_field_as_encrypted, :sekret, encryption_args

        Encryptor.db_encryption_key = default_key
      end

      describe 'salt generation method' do
        context 'salt is not set' do
          it 'updates the salt using Encryptor' do
            [nil, ''].each do |unset_value|
              expect(Encryptor).to receive(:generate_salt).and_return('new salt')
              subject.salt = unset_value
              subject.generate_salt
              expect(subject.salt).to eq 'new salt'
            end
          end
        end

        context 'salt is set' do
          it 'does not update the salt' do
            subject.salt = 'old salt'
            subject.generate_salt
            expect(subject.salt).to eq 'old salt'
          end
        end
      end

      describe 'decryption' do
        it 'decrypts by passing the salt and the underlying value to Encryptor' do
          subject.salt = 'asdf'
          subject.underlying_sekret = 'underlying'
          expect(Encryptor).to receive(:decrypt).with('underlying', 'asdf', nil) { 'unencrypted' }
          expect(subject.sekret).to eq 'unencrypted'
        end
      end

      describe 'encryption' do
        it 'calls the salt generation method' do
          expect(subject).to receive(:generate_salt).and_call_original
          subject.sekret = 'foobar'
        end

        context 'blank value' do
          before do
            allow(Encryptor).to receive(:encrypt)
            subject.underlying_sekret = 'notanilvalue'
          end

          context 'when the value is nil' do
            it 'stores a default nil value without trying to encrypt' do
              expect {
                subject.sekret = nil
              }.to change(subject, :underlying_sekret).to(nil)
            end
          end

          context 'when the value is blank' do
            it 'stores a default nil value without trying to encrypt' do
              expect {
                subject.sekret = ''
              }.to change(subject, :underlying_sekret).to(nil)
            end
          end
        end

        context 'non-blank value' do
          let(:salt) { Encryptor.generate_salt }
          let(:unencrypted_string) { 'unencrypted' }

          before do
            Encryptor.database_encryption_keys = {
              'foo' => 'fooencryptionkey',
              'bar' => 'headbangingdeathmetalkey'
            }
          end

          it 'encrypts by passing the value and salt to Encryptor' do
            subject.salt = salt
            expect(Encryptor).to receive(:encrypt).with('unencrypted', salt) { 'encrypted' }
            subject.sekret = unencrypted_string
            expect(subject.underlying_sekret).to eq 'encrypted'
          end

          it 'encrypts using the default db_encryption_key' do
            subject.salt = salt
            subject.sekret = unencrypted_string
            expect(Encryptor.decrypt(subject.underlying_sekret, subject.salt)).to eq(unencrypted_string)
          end

          context 'model has a value for encryption_key_label' do
            let(:columns) { [:sekret, :salt, :encryption_key_label] }

            before do
              allow(Encryptor).to receive(:current_encryption_key_label) { 'foo' }
              subject.salt = salt
              subject.encryption_key_label = 'foo'
              subject.sekret = unencrypted_string
              expect(subject.sekret).to eq(unencrypted_string)
            end

            it 'encrypts using the key corresponding to the label' do
              subject.salt = salt
              expect(Encryptor).to receive(:encrypt).with(unencrypted_string, salt).and_call_original
              subject.sekret = unencrypted_string
              expect(Encryptor.decrypt(subject.underlying_sekret, salt, 'foo')).to eq(unencrypted_string)
            end

            context 'and the key has been rotated' do
              it 'updates encryption_key_label in the record when encrypting' do
                allow(Encryptor).to receive(:current_encryption_key_label) { 'bar' }
                subject.sekret = 'nu'
                expect(subject.sekret).to eq('nu')
                expect(subject.encryption_key_label).to eq(Encryptor.current_encryption_key_label)
              end

              context 'and the model has another encrypted field' do
                let(:columns) { [:sekret, :salt, :sekret2, :sekret2_salt, :encryption_key_label] }
                let(:unencrypted_string2) { 'announce presence with authority' }

                before do
                  klass.class_eval do
                    def underlying_sekret2=(value)
                      @sekret2 = value
                    end

                    def underlying_sekret2
                      @sekret2
                    end
                  end
                  klass2.send :set_field_as_encrypted, :sekret2, encryption_args
                  subject.sekret2_salt = Encryptor.generate_salt
                  subject.sekret2 = unencrypted_string2
                end

                it 'reencrypts that field with the new key' do
                  allow(Encryptor).to receive(:current_encryption_key_label) { 'bar' }
                  subject.sekret = 'nu'
                  expect(Encryptor.decrypt(subject.underlying_sekret2, subject.salt, 'bar')).to eq(unencrypted_string2)
                end
              end
            end
          end
        end
      end

      describe 'alternative storage column is specified' do
        let(:columns) { [:sekret, :salt, :encrypted_sekret, :encryption_key_label] }
        let(:encryption_args) { { column: :encrypted_sekret } }

        it 'stores the encrypted value in that column' do
          expect(subject.encrypted_sekret).to eq nil
          subject.sekret = 'asdf'
          expect(subject.encrypted_sekret).to_not eq nil
          expect(subject.sekret).to eq 'asdf'
        end
      end
    end
  end
end
