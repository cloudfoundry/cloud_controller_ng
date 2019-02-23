module VCAP::CloudController
  module ValidateDatabaseKeys
    class ValidateDatabaseKeysError < StandardError; end
    class DatabaseEncryptionKeyMissingError < ValidateDatabaseKeysError; end
    class EncryptionKeySentinelMissingError < ValidateDatabaseKeysError; end
    class EncryptionKeySentinelDecryptionMismatchError < ValidateDatabaseKeysError; end

    class << self
      def validate!(config)
        can_decrypt_all_rows!(config)
        validate_encryption_key_values_unchanged!(config)
      end

      def can_decrypt_all_rows!(config)
        # Terminology: a present string has at least one char (so the nil value is not present)
        #              a blank string is the opposite of a present string
        # Note: String#blank? is true for non-empty strings containing only whitespace characters.
        # It's *possible* for an encryption key to fit this property but very bad form, so we don't worry about it.
        #
        # 1. Verify we have at least either a present :db_encryption_key or at least one :database_encryption.keys
        # 2. If we have any rows in the encrypted_classes with a non-present :encryption_key_label field require
        #    db_encryption_key
        # 3. Verify that all present :encryption_key_label fields are in :database_encryption.keys
        #
        original_key = config.get(:db_encryption_key)
        defined_encryption_key_labels = Set.new((config.get(:database_encryption) || {}).fetch(:keys, {}).keys)
        if original_key.blank? && defined_encryption_key_labels.empty?
          raise DatabaseEncryptionKeyMissingError.new('No database encryption keys are specified')
        end

        errors = []
        if legacy_db_encryption_key_in_use?(original_key)
          errors << "Encryption key from 'cc.db_encryption_key' is still in use, but no longer present in manifest.
                      See https://docs.cloudfoundry.org/adminguide/encrypting-cc-db.html for more information."
        end

        missing_key_labels = missing_database_encryption_keys(defined_encryption_key_labels)
        errors << missing_database_encryption_keys_message(missing_key_labels) if missing_key_labels.present?

        raise DatabaseEncryptionKeyMissingError.new(errors.join("\n")) if errors.present?
      end

      def validate_encryption_key_values_unchanged!(config)
        encryption_key_labels = config.get(:database_encryption, :keys)
        return unless encryption_key_labels.present?

        labels_with_changed_keys = []
        encryption_key_labels.each do |label, key_value|
          label_string = label.to_s
          sentinel_model = EncryptionKeySentinelModel.find(encryption_key_label: label_string)
          raise EncryptionKeySentinelMissingError unless sentinel_model.present?

          begin
            decrypted_value = Encryptor.decrypt_raw(
              sentinel_model.encrypted_value,
              key_value,
              sentinel_model.salt,
              iterations: sentinel_model.encryption_iterations
            )
          # A failed decryption occasionally results in a CipherError: bad decrypt instead of a garbled string
          rescue OpenSSL::Cipher::CipherError
            labels_with_changed_keys << label_string
            next
          end

          labels_with_changed_keys << label_string unless decrypted_value == sentinel_model.expected_value
        end

        if labels_with_changed_keys.present?
          raise EncryptionKeySentinelDecryptionMismatchError.new(sentinel_value_mismatch_message(labels_with_changed_keys))
        end

        existing_key_labels = encryption_key_labels.keys
        prune_unused_encryption_key_sentinels(existing_key_labels)
      end

      private

      def missing_database_encryption_keys(defined_encryption_key_labels)
        used_encryption_key_labels = Set.new(Encryptor.encrypted_classes.map do |klass|
          klass.constantize.select(:encryption_key_label).distinct.map(&:encryption_key_label)
        end.flatten.reject(&:blank?).map(&:to_sym))
        (used_encryption_key_labels - defined_encryption_key_labels).to_a
      end

      def rows_encrypted_with_original_key
        Encryptor.encrypted_classes.any? do |klass|
          klass.constantize.find(encryption_key_label: ['', nil])
        end
      end

      def legacy_db_encryption_key_in_use?(original_key)
        rows_encrypted_with_original_key && original_key.blank?
      end

      def missing_database_encryption_keys_message(missing_key_labels)
        key_labels = missing_key_labels.sort.map { |x| "'#{x}'" }.join(', ')
        "Encryption key(s) #{key_labels} are still in use but not present in 'cc.database_encryption.keys'
          See https://docs.cloudfoundry.org/adminguide/encrypting-cc-db.html for more information."
      end

      def sentinel_value_mismatch_message(labels_with_changed_keys)
        key_labels = labels_with_changed_keys.sort.map { |x| "'#{x}'" }.join(', ')
        "Encryption key(s) #{key_labels} have had their values changed. " \
        'Label and value pairs should not change, rather a new label and value pair should be added. ' \
        'See https://docs.cloudfoundry.org/adminguide/encrypting-cc-db.html for more information.'
      end

      def prune_unused_encryption_key_sentinels(existing_key_labels)
        stringified_existing_labels = existing_key_labels.map(&:to_s)
        unused_key_labels = EncryptionKeySentinelModel.exclude(encryption_key_label: stringified_existing_labels)
        unused_key_labels.map(&:destroy)
      end
    end
  end
end
