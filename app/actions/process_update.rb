require 'models/helpers/health_check_types'
require 'actions/metadata_update'

module VCAP::CloudController
  class ProcessUpdate
    class InvalidProcess < StandardError; end

    def initialize(user_audit_info, manifest_triggered: false)
      @user_audit_info = user_audit_info
      @manifest_triggered = manifest_triggered
    end

    def update(process, message, strategy_class)
      if process.web? && process.app.deploying?
        raise InvalidProcess.new('Cannot update this process while a deployment is in flight.')
      end

      strategy = strategy_class.new(message, process)
      process.db.transaction do
        process.lock!

        MetadataUpdate.update(process, message)

        if message.requested?(:health_check_type)
          process.health_check_type = message.health_check_type
          process.skip_process_version_update = true
        end

        process.command              = strategy.updated_command if message.requested?(:command)
        process.health_check_timeout = message.health_check_timeout if message.requested?(:health_check_timeout)
        process.health_check_invocation_timeout = message.health_check_invocation_timeout if message.requested?(:health_check_invocation_timeout)
        if message.requested?(:health_check_type) && message.health_check_type != HealthCheckTypes::HTTP
          process.health_check_http_endpoint = nil
        elsif message.requested?(:health_check_endpoint)
          process.health_check_http_endpoint = message.health_check_endpoint
        end

        process.save

        Repositories::ProcessEventRepository.record_update(process, @user_audit_info, message.audit_hash, manifest_triggered: @manifest_triggered)
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidProcess.new(e.message)
    end
  end
end
