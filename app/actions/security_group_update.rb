module VCAP::CloudController
  class SecurityGroupUpdate
    class Error < ::StandardError
    end

    def self.update(security_group, message)
      security_group.db.transaction do
        security_group.lock!

        security_group.name = message.name if message.requested? :name
        security_group.rules = message.rules if message.requested? :rules

        security_group.staging_default = message.staging if message.requested?(:globally_enabled) && !message.staging.nil?
        security_group.running_default = message.running if message.requested?(:globally_enabled) && !message.running.nil?

        security_group.save
      end

      security_group
    rescue Sequel::ValidationFailed => e
      if e.errors.on(:name)&.include?(:unique)
        raise Error.new("Security group with name '#{message.name}' already exists.")
      end

      raise Error.new(e.message)
    end
  end
end
