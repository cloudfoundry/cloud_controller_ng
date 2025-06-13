require 'models/helpers/health_check_types'
require 'actions/metadata_update'

module VCAP::CloudController
  class ProcessUpdate
    class InvalidProcess < StandardError; end

    def initialize(user_audit_info, manifest_triggered: false)
      @user_audit_info = user_audit_info
      @manifest_triggered = manifest_triggered
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def update(process, message, strategy_class)
      raise InvalidProcess.new('Cannot update this process while a deployment is in flight.') if process.web? && process.app.deploying?

      strategy = strategy_class.new(message, process)
      process.db.transaction do
        process.lock!

        MetadataUpdate.update(process, message)

        if message.requested?(:health_check_type)
          process.health_check_type = message.health_check_type
          process.skip_process_version_update = true
        end

        if message.requested?(:readiness_health_check_type)
          process.readiness_health_check_type = message.readiness_health_check_type
          process.skip_process_version_update = true
        end

        process.command              = strategy.updated_command if message.requested?(:command)
        process.user                 = message.user if message.requested?(:user)
        process.health_check_timeout = message.health_check_timeout if message.requested?(:health_check_timeout)

        process.health_check_invocation_timeout = message.health_check_invocation_timeout if message.requested?(:health_check_invocation_timeout)
        process.health_check_interval = message.health_check_interval if message.requested?(:health_check_interval)
        if message.requested?(:health_check_type) && message.health_check_type != HealthCheckTypes::HTTP
          process.health_check_http_endpoint = nil
          process.skip_process_version_update = true
        elsif message.requested?(:health_check_endpoint)
          process.health_check_http_endpoint = message.health_check_endpoint
          process.skip_process_version_update = true
        end

        process.readiness_health_check_invocation_timeout = message.readiness_health_check_invocation_timeout if message.requested?(:readiness_health_check_invocation_timeout)
        process.readiness_health_check_interval = message.readiness_health_check_interval if message.requested?(:readiness_health_check_interval)
        if message.requested?(:readiness_health_check_type) && message.readiness_health_check_type != HealthCheckTypes::HTTP
          process.readiness_health_check_http_endpoint = nil
          process.skip_process_version_update = true
        elsif message.requested?(:readiness_health_check_endpoint)
          process.readiness_health_check_http_endpoint = message.readiness_health_check_endpoint
          process.skip_process_version_update = true
        end

        process.save

        Repositories::ProcessEventRepository.record_update(process, @user_audit_info, message.audit_hash, manifest_triggered: @manifest_triggered)
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidProcess.new(e.message)
    end
    # rubocop:enable Metrics/CyclomaticComplexity
  end
end
