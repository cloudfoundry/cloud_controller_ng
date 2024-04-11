module VCAP::CloudController
  module Jobs
    module Runtime
      class ServiceOperationsInitialCleanup < VCAP::CloudController::Jobs::CCJob
        def perform
          cleanup_operations(ServiceInstanceOperation, ServiceInstance, :service_instance_id, :cleanup_failed_provision)
          cleanup_operations(ServiceBindingOperation, ServiceBinding, :service_binding_id, :cleanup_failed_bind)
          cleanup_operations(ServiceKeyOperation, ServiceKey, :service_key_id, :cleanup_failed_key)
          cleanup_operations(RouteBindingOperation, RouteBinding, :route_binding_id, nil)
        end

        def cleanup_operations(operation_model, instance_model, foreign_key, orphan_mitigator_method)
          operations_create_initial = operation_model.
                                      where(type: 'create', state: 'initial').
                                      where(updated_at_past_broker_timeout).
                                      select(:id, foreign_key)

          return if operations_create_initial.empty?

          operations_create_initial.each do |result|
            instance = instance_model.first(id: result[foreign_key])
            logger.info("#{instance_model.to_s.split('::').last} #{instance[:guid]} is stuck in state 'create'/'initial'. " \
                        "Setting state to 'failed' and triggering orphan mitigation.")
            operation_model.first(id: result[:id]).update(state: 'failed',
                                                          description: 'Operation was stuck in "initial" state. Set to "failed" by cleanup job.')

            orphan_mitigator.send(orphan_mitigator_method, instance) unless orphan_mitigator_method.nil?
          end
        end

        def updated_at_past_broker_timeout
          Sequel.lit(
            "updated_at < ? - INTERVAL '?' SECOND",
            Sequel::CURRENT_TIMESTAMP,
            broker_client_timeout_plus_margin
          )
        end

        def broker_client_timeout_plus_margin
          (config.get(:broker_client_timeout_seconds).to_i * 1.1).round
        end

        def job_name_in_configuration
          :service_operations_initial_cleanup
        end

        def max_attempts
          1
        end

        def config
          @config ||= Config.config
        end

        def orphan_mitigator
          @orphan_mitigator ||= VCAP::Services::ServiceBrokers::V2::OrphanMitigator.new
        end

        def logger
          @logger ||= Steno.logger('cc.background.service-operations-initial-cleanup')
        end
      end
    end
  end
end
