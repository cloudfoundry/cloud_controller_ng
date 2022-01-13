require 'active_model'

module VCAP::CloudController::Validators
  class AuthenticationValidator < ActiveModel::Validator
    def validate(record)
      ValidateAuthentication.new(record).validate
    end

    class ValidateAuthentication
      attr_reader :record

      def initialize(record)
        @record = record
      end

      def validate
        validate_authentication
        validate_authentication_credentials
      end

      def validate_authentication
        return if authentication_message.valid?

        record.errors.add(:authentication, authentication_message.errors[:base])
        record.errors.add(:authentication, authentication_message.errors[:type])
        record.errors.add(:authentication, authentication_message.errors[:credentials])
      end

      def authentication_message
        @authentication_message ||= VCAP::CloudController::AuthenticationMessage.new(record.authentication)
      end

      def authentication_credentials
        @authentication_credentials ||= VCAP::CloudController::BasicCredentialsMessage.new(authentication_credentials_hash)
      end

      def authentication_credentials_hash
        HashUtils.dig(record.authentication, :credentials)
      end

      def validate_authentication_credentials
        # AuthenticationMessage handles the hash error message for credentials
        if authentication_credentials_hash.is_a?(Hash) && !authentication_credentials.valid?
          record.errors.add(
            :authentication,
            message: "Field(s) #{authentication_credentials.errors.attribute_names.map(&:to_s)} must be valid: #{authentication_credentials.errors.full_messages}"
          )
        end
      end
    end
  end
end
