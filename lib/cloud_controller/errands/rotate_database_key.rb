module VCAP::CloudController
  class RotateDatabaseKey
    class << self
      def perform(batch_size: 1000)
        VCAP::CloudController::Encryptor.encrypted_classes.each do |klass|
          logger.info("rotating encryption key for class #{klass}")
          rotate_for_class(klass.constantize, batch_size)
          logger.info("done rotating encryption key for class #{klass}")
        end
      end

      private

      def rotate_for_class(klass, batch_size)
        loop do
          current_key_label = Encryptor.current_encryption_key_label
          rows = klass.exclude(encryption_key_label: current_key_label).limit(batch_size).all
          break if rows.count == 0

          rotate_batch(klass, rows)
        end
      end

      def rotate_batch(klass, rows)
        encrypted_fields = klass.encrypted_fields
        rows.each do |row|
          encrypt_row(encrypted_fields, row)
          row.save
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

      def logger
        @logger ||= Steno.logger('cc.rotate_database_key')
      end
    end
  end
end
