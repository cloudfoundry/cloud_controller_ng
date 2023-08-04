module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class ProcessPropertiesPresenter
          def to_hash(app:, **_)
            processes = app.processes.sort_by(&:type).map { |process| process_hash(process) }
            { processes: processes.presence }
          end

          def process_hash(process)
            {
              'type' => process.type,
              'instances' => process.instances,
              'memory' => add_units(process.memory),
              'disk_quota' => add_units(process.disk_quota),
              'log-rate-limit-per-second' => add_units_log_rate_limit(process.log_rate_limit),
              'command' => process.command,
              'health-check-type' => process.health_check_type,
              'health-check-http-endpoint' => process.health_check_http_endpoint,
              'health-check-invocation-timeout' => process.health_check_invocation_timeout,
              'health-check-interval' => process.health_check_interval,
              'readiness-health-check-type' => process.readiness_health_check_type,
              'readiness-health-check-http-endpoint' => process.readiness_health_check_http_endpoint,
              'readiness-health-check-invocation-timeout' => process.readiness_health_check_invocation_timeout,
              'readiness-health-check-interval' => process.readiness_health_check_interval,
              'timeout' => process.health_check_timeout,
            }.compact
          end

          def add_units(val)
            "#{val}M"
          end

          def add_units_log_rate_limit(val)
            return -1 if val == -1

            byte_converter.human_readable_byte_value(val)
          end

          def byte_converter
            ByteConverter.new
          end
        end
      end
    end
  end
end
