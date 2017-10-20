require 'securerandom'
require 'openssl'
require 'openssl/cipher'
require 'openssl/digest'

# require 'openssl/ossl'
require 'base64'

module VCAP::CloudController::Encryptor
  class << self
    ALGORITHM = 'AES-256-CBC'.freeze

    def generate_salt
      SecureRandom.hex(8).to_s
    end

    # takes no label, looks up in global config
    def encrypt(input, salt)
      return nil unless input

      label = current_encryption_key_label
      key = key_to_use(label)

      Base64.strict_encode64(run_cipher(make_cipher.encrypt, input, salt, key))
    end

    # this takes a label
    def decrypt(encrypted_input, salt, label=nil)
      return nil unless encrypted_input

      key = key_to_use(label)

      run_cipher(make_cipher.decrypt, Base64.decode64(encrypted_input), salt, key)
    end

    attr_writer :db_encryption_key
    attr_writer :database_encryption_keys
    attr_accessor :current_encryption_key_label

    private

    attr_reader :db_encryption_key
    attr_reader :database_encryption_keys

    def key_to_use(label)
      if database_encryption_keys.nil? || !database_encryption_keys.key?(label)
        return db_encryption_key
      end

      database_encryption_keys[label]
    end

    def make_cipher
      OpenSSL::Cipher.new(ALGORITHM)
    end

    def run_cipher(cipher, input, salt, key)
      if salt.length.eql?(8)
        # Backwards compatibility
        cipher.pkcs5_keyivgen(key, salt)
      else
        cipher.key = OpenSSL::PKCS5.pbkdf2_hmac(key, salt, 2048, 32, OpenSSL::Digest::SHA256.new)
        cipher.iv = salt
      end
      cipher.update(input).tap { |result| result << cipher.final }
    end
  end

  module FieldEncryptor
    extend ActiveSupport::Concern

    module ClassMethods
      attr_accessor :encrypted_fields

      def set_field_as_encrypted(field_name, options={})
        field_name = field_name.to_sym
        salt_name = (options[:salt] || "#{field_name}_salt").to_sym
        generate_salt_name = "generate_#{salt_name}".to_sym
        storage_column = options[:column]

        field_entry = { field_name: field_name, salt_name: salt_name }

        # Store the list of encrypted fields for use during key rotation
        if self.encrypted_fields.nil?
          self.encrypted_fields = [field_entry]
        else
          self.encrypted_fields.append(field_entry)
        end

        unless columns.include?(salt_name)
          raise "Salt field `#{salt_name}` does not exist"
        end

        raise 'Field "encryption_key_label" does not exist' unless columns.include?(:encryption_key_label)

        define_method generate_salt_name do
          return unless send(salt_name).blank?
          send "#{salt_name}=", VCAP::CloudController::Encryptor.generate_salt
        end

        if storage_column
          define_method field_name do
            send storage_column
          end

          define_method "#{field_name}=" do |value|
            send "#{storage_column}=", value
          end
        end

        define_method "#{field_name}_with_encryption" do
          VCAP::CloudController::Encryptor.decrypt send("#{field_name}_without_encryption"), send(salt_name), self.encryption_key_label
        end
        alias_method_chain field_name, 'encryption'

        define_method "#{field_name}_with_encryption=" do |value|
          send generate_salt_name

          if value.blank?
            send "#{field_name}_without_encryption=", nil
          elsif !VCAP::CloudController::Encryptor.current_encryption_key_label.nil? && self.encryption_key_label != VCAP::CloudController::Encryptor.current_encryption_key_label
            send(:db).transaction do
              e_fields = self.class.encrypted_fields
              if !e_fields.nil?
                self.class.encrypted_fields.each do |field|
                  if !field[:field_name].eql?(field_name)
                    send "#{field[:field_name]}_without_encryption=", VCAP::CloudController::Encryptor.encrypt(send(field[:field_name]), send(field[:salt_name]))
                  else
                    send "#{field_name}_without_encryption=", VCAP::CloudController::Encryptor.encrypt(value, send(salt_name))
                  end
                end
              end
              self.encryption_key_label = VCAP::CloudController::Encryptor.current_encryption_key_label
            end
          else
            # will use the current key label to encrypt
            encrypted_value = VCAP::CloudController::Encryptor.encrypt(value, send(salt_name))
            send "#{field_name}_without_encryption=", encrypted_value
          end
        end
        alias_method_chain "#{field_name}=", 'encryption'
      end

      private :set_field_as_encrypted
    end
  end
end
