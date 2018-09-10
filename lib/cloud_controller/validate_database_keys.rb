module VCAP::CloudController
  module ValidateDatabaseKeys
    class Error < StandardError; end
    class DbEncryptionKeyMissingError < Error; end

    class << self
      def validate!(config)
        return if config.get(:db_encryption_key)

        Encryptor.encrypted_classes.each do |klass|
          if klass.constantize.find(encryption_key_label: nil)
            raise DbEncryptionKeyMissingError.new
          end
        end
      end
    end
  end
end
