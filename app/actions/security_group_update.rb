module VCAP::CloudController
  class SecurityGroupUpdate
    MYSQL_INVALID_VALUE_ERROR = 1366

    class Error < ::StandardError
    end

    class << self
      def update(security_group, message)
        security_group.db.transaction do
          security_group.lock!

          security_group.name = message.name if message.requested? :name
          security_group.rules = message.rules if message.requested? :rules

          security_group.staging_default = message.staging if message.requested?(:globally_enabled) && !message.staging.nil?
          security_group.running_default = message.running if message.requested?(:globally_enabled) && !message.running.nil?

          security_group.save

          AsgLatestUpdate.renew
        end

        security_group
      rescue Sequel::ValidationFailed => e
        validation_error!(e, message)
      rescue Sequel::DatabaseError => e
        invalid_value_error!(e)
      end

      private

      def validation_error!(error, message)
        if error.errors.on(:name)&.include?(:unique)
          error!("Security group with name '#{message.name}' already exists.")
        end

        error!(error.message)
      end

      def invalid_value_error!(error)
        if error.wrapped_exception.is_a?(Mysql2::Error) && error.wrapped_exception.error_number == MYSQL_INVALID_VALUE_ERROR
          if /column.*name/ =~ error.message
            error!('Security group name contains invalid characters.')
          elsif /column.*rules/ =~ error.message
            error!('Security group rules contain invalid characters.')
          end
        end

        raise error
      end

      def error!(message)
        raise Error.new(message)
      end
    end
  end
end
