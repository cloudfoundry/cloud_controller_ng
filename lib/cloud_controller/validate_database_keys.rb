module VCAP::CloudController
  module ValidateDatabaseKeys
    class DatabaseEncryptionKeyMissingError < StandardError; end

    class << self
      def can_decrypt_all_rows!(config)
        # 1. Verify we have at least one of :db_encryption_key or at least :database_encryption.keys
        # 2. If we have any rows in the encrypted_classes with a nil :encryption_key_label field require
        #    db_encryption_key
        # 3. Verify that all non-nil :encryption_key_label fields are in :database_encryption.keys
        #
        original_key = config.get(:db_encryption_key)
        defined_encryption_key_labels = Set.new((config.get(:database_encryption) || {}).fetch(:keys, {}).keys)
        if original_key.nil? && defined_encryption_key_labels.empty?
          raise DatabaseEncryptionKeyMissingError.new('No database encryption keys are specified')
        end

        msgs = []

        # 2. nil encryption_key_label fields require :db_encryption_key
        if rows_encrypted_with_original_key && original_key.nil?
          msgs << "Encryption key from 'cc.db_encryption_key' is still in use, but no longer present in manifest."
        end

        # 3: non-nil encryption_key_label fields require labels defined in :database_encryption
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
        end.flatten.compact.map(&:to_sym))
        (used_encryption_key_labels - defined_encryption_key_labels).to_a
      end

      def rows_encrypted_with_original_key
        Encryptor.encrypted_classes.any? do |klass|
          klass.constantize.find(encryption_key_label: nil)
        end
      end
    end
  end
end
