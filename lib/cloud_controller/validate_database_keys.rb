module VCAP::CloudController
  module ValidateDatabaseKeys
    class DatabaseEncryptionKeyMissingError < StandardError; end

    class << self
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

        msgs = []

        # 2. blank encryption_key_label fields require :db_encryption_key
        if rows_encrypted_with_original_key && original_key.blank?
          msgs << "Encryption key from 'cc.db_encryption_key' is still in use, but no longer present in manifest."
        end

        # 3: non-blank encryption_key_label fields require labels defined in :database_encryption
        missing_key_labels = missing_db_encryption_keys(defined_encryption_key_labels)
        if !missing_key_labels.empty?
          key_names = missing_key_labels.sort.map { |x| "'#{x}'" }.join(', ')
          msgs << "Encryption key(s) #{key_names} are still in use but not present in 'cc.database_encryption.keys'"
        end

        if msgs.size > 0
          raise DatabaseEncryptionKeyMissingError.new(msgs.join("\n"))
        end
      end

      private

      def missing_db_encryption_keys(defined_encryption_key_labels)
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
    end
  end
end
