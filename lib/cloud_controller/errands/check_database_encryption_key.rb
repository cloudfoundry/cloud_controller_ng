module VCAP::CloudController
  class CheckDatabaseEncryptionKey
    class << self
      def perform
        @logger = Steno.logger('cc.check_database_encryption_key')

        if Encryptor.current_encryption_key_label.blank?
          logger.error('No current encryption key label is set')
          exit 1
        end

        rows_needing_rotation = count_rows_needing_rotation
        if rows_needing_rotation > 0
          logger.info("#{rows_needing_rotation} row(s) need re-encryption with the current key")
          exit 2
        end

        logger.info('All rows are encrypted with the current key')
        exit 0
      rescue => e
        logger.error("Unexpected error: #{e.class}: #{e.message}")
        exit 1
      end

      private

      attr_accessor :logger

      def count_rows_needing_rotation
        current_key_label = Encryptor.current_encryption_key_label
        Encryptor.encrypted_classes.sum do |klass|
          klass.constantize
               .exclude(encryption_key_label: current_key_label)
               .or(encryption_key_label: nil)
               .count
        end
      end
    end
  end
end
