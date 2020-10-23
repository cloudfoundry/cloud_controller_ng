require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Encryptor do
    let(:salt) { Encryptor.generate_salt }
    let(:encryption_iterations) { Encryptor::ENCRYPTION_ITERATIONS }

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

      it 'does not encrypt null values' do
        expect(Encryptor.encrypt(nil, salt)).to be_nil
      end

      context 'when database_encryption_keys has been set' do
        let(:salt) { 'FFFFFFFFFFFFFFFF' }
        let(:encrypted_death_string) { 'UsFVj9hjohvzOwlJQ4tqHA==' }
        let(:encrypted_legacy_string) { 'a6FHdu9k3+CCSjvzIX+i7w==' }

        before(:each) do
          Encryptor.db_encryption_key = 'legacy-crypto-key'
          Encryptor.database_encryption_keys = {
            foo: 'fooencryptionkey',
            death: 'headbangingdeathmetalkey'
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
        let(:encrypted_legacy_string) { 'a6FHdu9k3+CCSjvzIX+i7w==' }

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

    describe '.pbkdf2_hmac_iterations=' do
      after do
        Encryptor.pbkdf2_hmac_iterations = Encryptor::ENCRYPTION_ITERATIONS
      end

      context 'when set to a value higher than Encryptor::ENCRYPTION_ITERATIONS' do
        it 'sets pbkdf2_hmac_iterations' do
          Encryptor.pbkdf2_hmac_iterations = 38_000
          expect(Encryptor.pbkdf2_hmac_iterations).to eq 38_000
        end
      end

      context 'when set to a value lower than Encryptor::ENCRYPTION_ITERATIONS' do
        it 'remains set to ENCRYPTION_ITERATIONS' do
          Encryptor.pbkdf2_hmac_iterations = 1
          expect(Encryptor.pbkdf2_hmac_iterations).to eq Encryptor::ENCRYPTION_ITERATIONS
        end
      end
    end

    describe '.decrypt' do
      let(:unencrypted_string) { 'some-string' }

      before(:each) do
        Encryptor.db_encryption_key = 'legacy-crypto-key'
        Encryptor.database_encryption_keys = {}
      end

      it 'returns the original string' do
        encrypted_string = Encryptor.encrypt(unencrypted_string, salt)
        expect(Encryptor.decrypt(encrypted_string, salt, iterations: encryption_iterations)).to eq(unencrypted_string)
      end

      it 'returns nil if the encrypted string is nil' do
        expect(Encryptor.decrypt(nil, salt, iterations: encryption_iterations)).to be_nil
      end

      context 'when database_encryption_keys is configured' do
        before(:each) do
          Encryptor.database_encryption_keys = {
            foo: 'fooencryptionkey',
            death: 'headbangingdeathmetalkey'
          }
        end

        context 'when no encryption key label is passed' do
          before(:each) do
            allow(Encryptor).to receive(:current_encryption_key_label) { nil }
          end

          it 'decrypts using #db_encryption_key' do
            encrypted_string = Encryptor.encrypt(unencrypted_string, salt)
            expect(Encryptor).to receive(:db_encryption_key).and_call_original.at_least(:once)
            expect(Encryptor.decrypt(encrypted_string, salt, iterations: encryption_iterations)).to eq(unencrypted_string)
          end
        end

        context 'when encryption was done using a labelled key' do
          before do
            allow(Encryptor).to receive(:current_encryption_key_label) { 'foo' }
          end

          it 'decrypts using the key specified by the passed label' do
            encrypted_string = Encryptor.encrypt(unencrypted_string, salt)
            expect(Encryptor.decrypt(encrypted_string, salt, label: 'foo', iterations: encryption_iterations)).to eq(unencrypted_string)
          end

          context 'when no key label is passed for decryption' do
            it 'fails to decrypt the encrypted string successfully' do
              encrypted_string = Encryptor.encrypt(unencrypted_string, salt)

              result = begin
                Encryptor.decrypt(encrypted_string, salt, iterations: encryption_iterations)
              rescue OpenSSL::Cipher::CipherError => e
                e.message
              end

              expect(result).not_to eq(unencrypted_string)
            end
          end

          context 'when the wrong label is passed for decryption' do
            it 'fails to decrypt the encrypted string successfully' do
              encrypted_string = Encryptor.encrypt(unencrypted_string, salt)

              result = begin
                Encryptor.decrypt(encrypted_string, salt, label: 'death', iterations: encryption_iterations)
              rescue OpenSSL::Cipher::CipherError => e
                e.message
              end

              expect(result).not_to eq(unencrypted_string)
            end
          end
        end
      end

      context 'when the salt is only 8 bytes (legacy mode)' do
        let(:salt) { SecureRandom.hex(4).to_s }

        it 'decrypts correctly' do
          encrypted_string = Encryptor.encrypt(unencrypted_string, salt)
          expect(Encryptor.decrypt(encrypted_string, salt, iterations: encryption_iterations)).to eq(unencrypted_string)
        end
      end
    end
  end

  RSpec.describe Encryptor::FieldEncryptor do
    let(:base_class) do
      Class.new do
        include VCAP::CloudController::Encryptor::FieldEncryptor
        def self.columns
          raise '<dynamic class>.columns: not implemented'
        end

        def self.name
          'BaseClass'
        end

        def self.table_name
          :table_name
        end

        def db; end
      end
    end

    let(:db) { double(Sequel::Database) }

    before do
      allow(base_class).to receive(:columns) { columns }
      allow(db).to receive(:transaction) do |&block|
        block.call
      end
      base_class.send :attr_accessor, *columns # emulate Sequel super methods
    end

    describe '#set_field_as_encrypted' do
      context 'model does not have the salt column' do
        let(:columns) { [:id, :name, :size, :encryption_key_label] }

        context 'default name' do
          it 'raises an error' do
            expect {
              base_class.send :set_field_as_encrypted, :name
            }.to raise_error(RuntimeError, /salt/)
          end
        end

        context 'explicit name' do
          it 'raises an error' do
            expect {
              base_class.send :set_field_as_encrypted, :name, salt: :foobar
            }.to raise_error(RuntimeError, /foobar/)
          end
        end
      end

      context 'model has the salt column' do
        let(:columns) { [:id, :name, :size, :salt, :encryption_key_label, :encryption_iterations] }

        it 'does not raise an error' do
          expect {
            base_class.send :set_field_as_encrypted, :name
          }.to_not raise_error
        end

        it 'creates a salt generation method' do
          base_class.send :set_field_as_encrypted, :name
          expect(base_class.instance_methods).to include(:generate_salt)
        end

        it 'stores its classname' do
          base_class.send :set_field_as_encrypted, :name

          expect(Encryptor.encrypted_classes).to include(base_class.name)
        end

        context 'explicit name' do
          let(:columns) { [:id, :name, :size, :foobar, :encryption_key_label, :encryption_iterations] }

          it 'does not raise an error' do
            expect {
              base_class.send :set_field_as_encrypted, :name, salt: :foobar
            }.to_not raise_error
          end

          it 'creates a salt generation method' do
            base_class.send :set_field_as_encrypted, :name, salt: :foobar
            expect(base_class.instance_methods).to include(:generate_foobar)
          end
        end
      end

      context 'model does not have the "encryption_key_label" column' do
        let(:columns) { [:id, :name, :salt, :size] }

        it 'raises an error' do
          expect {
            base_class.send :set_field_as_encrypted, :name
          }.to raise_error(RuntimeError, /encryption_key_label/)
        end
      end

      context 'model does not have the "encryption_iterations" column' do
        let(:columns) { [:id, :name, :salt, :encryption_key_label] }

        it 'raises and error' do
          expect { base_class.send :set_field_as_encrypted, :name }.to raise_error(RuntimeError, /encryption_iterations/)
        end
      end
    end

    describe 'field-specific methods' do
      let(:columns) { [:sekret, :salt, :encryption_key_label, :encryption_iterations] }
      let(:model_class) do
        Class.new(base_class) do
          set_field_as_encrypted :sekret

          def self.name
            'ModelClass'
          end
        end
      end
      let(:subject) { model_class.new }
      let(:default_key) { 'somerandomkey' }
      let(:encryption_iterations) { Encryptor::ENCRYPTION_ITERATIONS }

      before do
        subject.encryption_iterations = encryption_iterations
        allow(subject).to receive(:db) { db }

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

      describe 'encryption iteration' do
        it 'updates to the newest iteration value' do
          allow(Encryptor).to receive(:pbkdf2_hmac_iterations).and_return(2048)
          subject.encryption_iterations = 2048
          subject.salt = 'some salt'
          expect(Encryptor).to receive(:encrypt).with('hello', 'some salt')

          allow(Encryptor).to receive(:pbkdf2_hmac_iterations).and_return(100_001)
          subject.sekret = 'hello'
          expect(subject.encryption_iterations).to eq 100_001
        end
      end

      describe 'decryption' do
        it 'decrypts by passing the salt and the underlying value to Encryptor' do
          subject.salt = 'asdf'
          subject.sekret_without_encryption = 'underlying'
          expect(Encryptor).to receive(:decrypt).with('underlying', 'asdf', iterations: encryption_iterations, label: nil) { 'unencrypted' }
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
            subject.sekret = 'notanilvalue'
          end

          context 'when the value is nil' do
            it 'stores a default nil value without trying to encrypt' do
              expect(subject.sekret_without_encryption).to_not be_nil
              expect {
                subject.sekret = nil
              }.to change(subject, :sekret_without_encryption).to(nil)
            end
          end

          context 'when the value is blank' do
            it 'stores a default nil value without trying to encrypt' do
              expect(subject.sekret_without_encryption).to_not be_nil
              expect {
                subject.sekret = ''
              }.to change(subject, :sekret_without_encryption).to(nil)
            end
          end
        end

        context 'non-blank value' do
          let(:salt) { Encryptor.generate_salt }
          let(:unencrypted_string) { 'unencrypted' }

          before do
            Encryptor.database_encryption_keys = {
              foo: 'fooencryptionkey',
              bar: 'headbangingdeathmetalkey'
            }
          end

          it 'encrypts by passing the value and salt to Encryptor' do
            subject.salt = salt
            expect(Encryptor).to receive(:encrypt).with('unencrypted', salt) { 'encrypted' }
            subject.sekret = unencrypted_string
            expect(subject.sekret_without_encryption).to eq 'encrypted'
          end

          it 'encrypts using the default database_encryption_keys' do
            subject.salt = salt
            subject.sekret = unencrypted_string
            expect(Encryptor.decrypt(subject.sekret_without_encryption, subject.salt, iterations: encryption_iterations)).to eq(unencrypted_string)
          end

          context 'model has a value for encryption_key_label' do
            let(:columns) { [:sekret, :salt, :encryption_key_label, :encryption_iterations] }

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
              expect(Encryptor.decrypt(subject.sekret_without_encryption, salt, label: 'foo', iterations: encryption_iterations)).to eq(unencrypted_string)
            end
          end
        end
      end

      describe 'key rotation' do
        let(:salt) { Encryptor.generate_salt }
        let(:unencrypted_string) { 'unencrypted' }

        before do
          Encryptor.database_encryption_keys = {
            foo: 'fooencryptionkey',
            bar: 'headbangingdeathmetalkey'
          }
          allow(Encryptor).to receive(:current_encryption_key_label) { 'foo' }
          subject.sekret = unencrypted_string
          expect(subject.sekret).to eq(unencrypted_string)
          allow(Encryptor).to receive(:current_encryption_key_label) { 'bar' }
        end

        it 'updates encryption_key_label in the record when encrypting' do
          expect(subject.encryption_key_label).to eq('foo')
          subject.sekret = 'nu'
          expect(subject.sekret).to eq('nu')
          expect(subject.encryption_key_label).to eq('bar')
        end

        context 'and the field is serialized (and/or has other alias method chains)' do
          let(:serialized_model) do
            Class.new(base_class) do
              set_field_as_encrypted :sekret

              def self.name
                'SerializedModelClass'
              end

              def sekret_with_serialization
                MultiJson.load(sekret_without_serialization)
              end

              def sekret_with_serialization=(sekret)
                self.sekret_without_serialization = MultiJson.dump(sekret)
              end

              alias_method 'sekret_without_serialization', 'sekret'
              alias_method 'sekret', 'sekret_with_serialization'
              alias_method 'sekret_without_serialization=', 'sekret='
              alias_method 'sekret=', 'sekret_with_serialization='
            end
          end

          let(:subject) { serialized_model.new }
          let(:unencrypted_string) { { 'foo' => 'bar' } }

          it 're-encrypts the field after it has been serialized (the encryptor only works for strings, not hashes)' do
            subject.sekret = { 'foo' => 'bar' }
            expect(subject.sekret_without_serialization).to eq(%({\"foo\":\"bar\"}))
            expect(subject.sekret).to eq({ 'foo' => 'bar' })
            expect(subject.encryption_key_label).to eq(Encryptor.current_encryption_key_label)
          end
        end

        context 'and the model has another encrypted field' do
          let(:columns) { [:sekret, :salt, :sekret2, :sekret2_salt, :encryption_key_label, :encryption_iterations] }
          let(:unencrypted_string2) { 'announce presence with authority' }
          let(:multi_field_class) do
            Class.new(base_class) do
              set_field_as_encrypted :sekret
              set_field_as_encrypted :sekret2, { salt: 'sekret2_salt' }

              def db; end

              def self.name
                'MultiFieldClass'
              end
            end
          end

          let(:subject) { multi_field_class.new }

          before do
            allow(Encryptor).to receive(:current_encryption_key_label) { 'foo' }
            subject.sekret = unencrypted_string
            subject.sekret2 = unencrypted_string2
          end

          it 're-encrypts that field with the new key' do
            allow(Encryptor).to receive(:current_encryption_key_label) { 'bar' }
            subject.sekret = 'nu'

            expect(subject.encryption_key_label).to eq('bar')
            expect(Encryptor.decrypt(subject.sekret_without_encryption, subject.salt, label: 'bar', iterations: encryption_iterations)).to eq('nu')
            expect(Encryptor.decrypt(subject.sekret2_without_encryption, subject.sekret2_salt, label: 'bar', iterations: encryption_iterations)).to eq(unencrypted_string2)
          end
        end

        context 'and the model is a subclass of the class with encrypted fields' do
          let(:columns) { [:sekret, :salt, :sekret2, :sekret2_salt, :encryption_key_label, :encryption_iterations] }
          let(:unencrypted_string2) { 'announce presence with authority' }

          let(:sti_class_parent) do
            Class.new(base_class) do
              set_field_as_encrypted :sekret
              set_field_as_encrypted :sekret2, { salt: 'sekret2_salt' }

              def db; end

              def self.name
                'StiClassParent'
              end
            end
          end

          let(:sti_class_child) do
            Class.new(sti_class_parent) do
              def self.name
                'StiClassChild'
              end
            end
          end

          let(:subject) { sti_class_child.new }

          before do
            allow(Encryptor).to receive(:encrypt).and_call_original
            allow(Encryptor).to receive(:current_encryption_key_label) { 'foo' }
            subject.sekret = unencrypted_string
            subject.sekret2 = unencrypted_string2
            allow(Encryptor).to receive(:current_encryption_key_label) { 'bar' }
          end

          it 're-encrypts all fields from the superclass' do
            expect(subject.encryption_key_label).to eq('foo')
            subject.sekret = 'nu'

            expect(subject.sekret).to eq('nu')

            expect(subject.encryption_key_label).to eq('bar')
            expect(Encryptor.decrypt(subject.sekret_without_encryption, subject.salt, label: 'bar', iterations: encryption_iterations)).to eq('nu')
            expect(Encryptor.decrypt(subject.sekret2_without_encryption, subject.sekret2_salt, label: 'bar', iterations: encryption_iterations)).to eq(unencrypted_string2)
          end
        end
      end

      describe 'pbkdf2_hmac iterations' do
        let(:salt) { Encryptor.generate_salt }
        let(:unencrypted_string) { 'unencrypted' }

        before do
          Encryptor.database_encryption_keys = {
            foo: 'fooencryptionkey'
          }
          allow(Encryptor).to receive(:current_encryption_key_label) { 'foo' }
          allow(Encryptor).to receive(:pbkdf2_hmac_iterations) { 2048 }
          subject.sekret = unencrypted_string
          expect(subject.sekret).to eq(unencrypted_string)
          allow(Encryptor).to receive(:pbkdf2_hmac_iterations) { 100_001 }
        end

        it 'updates encryption_iterations in the record when encrypting' do
          expect(subject.encryption_iterations).to eq(2048)
          subject.sekret = 'nu'
          expect(subject.sekret).to eq('nu')
          expect(subject.encryption_iterations).to eq(100_001)
        end

        context 'and the model has another encrypted field' do
          let(:columns) { [:sekret, :salt, :sekret2, :sekret2_salt, :encryption_key_label, :encryption_iterations] }
          let(:unencrypted_string2) { 'announce presence with authority' }
          let(:multi_field_class) do
            Class.new(base_class) do
              set_field_as_encrypted :sekret
              set_field_as_encrypted :sekret2, { salt: 'sekret2_salt' }

              def db; end

              def self.name
                'MultiFieldClass'
              end
            end
          end

          let(:subject) { multi_field_class.new }

          before do
            allow(Encryptor).to receive(:pbkdf2_hmac_iterations) { 2048 }
            subject.sekret = unencrypted_string
            subject.sekret2 = unencrypted_string2
          end

          it 're-encrypts all fields with the new iteration count' do
            allow(Encryptor).to receive(:pbkdf2_hmac_iterations) { 100_001 }
            subject.sekret = 'nu'

            expect(subject.encryption_iterations).to eq(100_001)

            expect(Encryptor.decrypt(subject.sekret_without_encryption, subject.salt, label: 'foo', iterations: 100_001)).to eq('nu')
            expect(Encryptor.decrypt(subject.sekret2_without_encryption, subject.sekret2_salt, label: 'foo', iterations: 100_001)).to eq(unencrypted_string2)
          end
        end

        context 'and the model is a subclass of the class with encrypted fields' do
          let(:columns) { [:sekret, :salt, :sekret2, :sekret2_salt, :encryption_key_label, :encryption_iterations] }
          let(:unencrypted_string2) { 'announce presence with authority' }

          let(:sti_class_parent) do
            Class.new(base_class) do
              set_field_as_encrypted :sekret
              set_field_as_encrypted :sekret2, { salt: 'sekret2_salt' }

              def db; end

              def self.name
                'StiClassParent'
              end
            end
          end

          let(:sti_class_child) do
            Class.new(sti_class_parent) do
              def self.name
                'StiClassChild'
              end
            end
          end

          let(:subject) { sti_class_child.new }

          before do
            allow(Encryptor).to receive(:encrypt).and_call_original
            allow(Encryptor).to receive(:pbkdf2_hmac_iterations) { 2048 }
            subject.sekret = unencrypted_string
            subject.sekret2 = unencrypted_string2
            allow(Encryptor).to receive(:pbkdf2_hmac_iterations) { 100_001 }
          end

          it 're-encrypts all fields from the superclass' do
            expect(subject.encryption_iterations).to eq(2048)
            subject.sekret = 'nu'

            expect(subject.sekret).to eq('nu')

            expect(subject.encryption_iterations).to eq(100_001)
            expect(Encryptor.decrypt(subject.sekret_without_encryption, subject.salt, label: 'foo', iterations: 100_001)).to eq('nu')
            expect(Encryptor.decrypt(subject.sekret2_without_encryption, subject.sekret2_salt, label: 'foo', iterations: 100_001)).to eq(unencrypted_string2)
          end
        end
      end

      describe 'alternative storage column is specified' do
        let(:columns) { [:sekret, :salt, :encrypted_sekret, :encryption_key_label, :encryption_iterations] }

        let(:model_class) do
          Class.new(base_class) do
            set_field_as_encrypted :sekret, { column: :encrypted_sekret }
          end
        end

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
