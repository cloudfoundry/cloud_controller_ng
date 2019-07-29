require 'repositories/process_event_repository'
require 'models/helpers/process_types'
require 'models/helpers/health_check_types'

module VCAP::CloudController
  class ProcessCreate
    def initialize(user_audit_info, manifest_triggered: false)
      @user_audit_info = user_audit_info
      @manifest_triggered = manifest_triggered
    end

    def create(app, args)
      type = args[:type]
      attrs = args.merge({
        diego:             true,
        instances:         default_instance_count(type),
        health_check_type: default_health_check_type(type),
        metadata:          {},
      })
      attrs[:guid] = app.guid if type == ProcessTypes::WEB

      process = nil
      app.class.db.transaction do
        process = app.add_process(attrs)
        route_mappings = process.route_mappings
        if route_mappings.count > 0
          process.update(ports: route_mappings.map(&:app_port))
        end
        Repositories::ProcessEventRepository.record_create(process, @user_audit_info, manifest_triggered: @manifest_triggered)
      end

      process
    end

    private

    def default_health_check_type(type)
      type == ProcessTypes::WEB ? HealthCheckTypes::PORT : HealthCheckTypes::PROCESS
    end

    def default_instance_count(type)
      type == ProcessTypes::WEB ? 1 : 0
    end
  end
end
