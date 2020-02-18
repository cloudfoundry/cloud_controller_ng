module VCAP::CloudController
  class SecurityGroupCreate
    class Error < ::StandardError
    end

    class << self
      def create(message)
        security_group = nil

        SecurityGroup.db.transaction do
          security_group = SecurityGroup.create(
            name: message.name
          )
        end
        security_group
      rescue Sequel::ValidationFailed => e
        validation_error!(e, message)
      end

      private

      def validation_error!(error, message)
        if error.errors.on(:name)&.include?(:unique)
          error!("Security group with name '#{message.name}' already exists.")
        end

        error!(error.message)
      end

      def error!(message)
        raise Error.new(message)
      end
    end
  end
end
