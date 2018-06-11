module VCAP::CloudController
  class RotateDatabaseKey
    class << self
      def perform
        VCAP::CloudController::Encryptor.encrypted_classes.each do |klass|
          logger.info("rotating encryption key for class #{klass}")
          perform_for_klass(klass.constantize)
          logger.info("done rotating encryption key for class #{klass}")
        end
      end

      private

      def perform_for_klass(klass)
        current_key_label = Encryptor.current_encryption_key_label
        rows = klass.exclude(encryption_key_label: current_key_label)
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
