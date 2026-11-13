# rubocop:disable Rails/Exit
module VCAP::CloudController
  class CheckDatabaseKey
    class << self
      def perform
        @logger = Steno.logger('cc.check_database_key')

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
      rescue StandardError => e
        logger.error("Unexpected error: #{e.class}: #{e.message}")
        exit 1
      end

      private

      attr_accessor :logger

      def count_rows_needing_rotation
        current_key_label = Encryptor.current_encryption_key_label
        Encryptor.encrypted_classes.sum do |klass|
          model = klass.constantize
          rows = model.exclude(encryption_key_label: current_key_label).or(encryption_key_label: nil)
          total = rows.count
          if total > 0
            rows.group_and_count(:encryption_key_label).each do |row|
              label = row[:encryption_key_label].nil? ? '(nil)' : row[:encryption_key_label]
              logger.debug("Table #{model.table_name}: #{row[:count]} row(s) with encryption_key_label=#{label}")
            end
          end
          total
        end
      end
    end
  end
end
# rubocop:enable Rails/Exit
