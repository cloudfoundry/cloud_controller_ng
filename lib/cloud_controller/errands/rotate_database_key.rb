module VCAP::CloudController
  class RotateDatabaseKey
    class << self
      def perform(batch_size: 1000)
        @logger = Steno.logger('cc.rotate_database_key')

        no_encryption_key! unless Encryptor.current_encryption_key_label.present?

        Encryptor.encrypted_classes.each do |klass|
          logger.info("Rotating encryption key for class #{klass}")
          rotate_for_class(klass.constantize, batch_size)
          logger.info("Done rotating encryption key for class #{klass}")
        end
      end

      private

      attr_accessor :logger

      def no_encryption_key!
        raise CloudController::Errors::ApiError.new_from_details('NoCurrentEncryptionKey')
      end

      def rotate_for_class(klass, batch_size)
        current_key_label = Encryptor.current_encryption_key_label
        rows_needing_rotation = klass.
                                exclude(encryption_key_label: current_key_label).
                                or(encryption_key_label: nil)

        logger.info("#{rows_needing_rotation.count} rows of #{klass} are not encrypted with the current key and will be rotated")
        loop do
          rows = rows_needing_rotation.
                 limit(batch_size).
                 all
          break if rows.count == 0

          klass.instance_exec do
            @allow_manual_timestamp_update = true
          end
          klass.descendants.select { |m| m.to_s.start_with?('VCAP::CloudController::') }.each do |model|
            model.instance_exec { @allow_manual_timestamp_update = true }
          end

          rotate_batch(klass, rows)
          logger.info("Rotated batch of #{rows.count} rows of #{klass}")
        end
      end

      def rotate_batch(klass, rows)
        encrypted_fields = klass.all_encrypted_fields
        rows.each do |row|
          row.db.transaction do
            row.lock!
            encrypt_row(encrypted_fields, row)
            row.modified!(:updated_at)
            row.save(validate: false, changed: true)
          rescue Sequel::NoExistingObject
            raise Sequel::Rollback
          rescue StandardError => e
            logger.error("Error '#{e.class}' occurred while updating record: #{row.class}, id: #{row.id}")
            raise
          end
        end
      end

      def encrypt_row(encrypted_fields, row)
        encrypted_fields.each do |field|
          encrypt_field(field, row)
        end
      end

      def encrypt_field(field, row)
        field_name = field[:field_name]
        row.public_send("#{field_name}=".to_sym, row.public_send(field_name.to_sym))
      end
    end
  end
end
