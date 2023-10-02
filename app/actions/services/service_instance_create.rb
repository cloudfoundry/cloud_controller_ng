require 'actions/services/database_error_service_resource_cleanup'
require 'jobs/v2/services/service_instance_state_fetch'

module VCAP::CloudController
  class ServiceInstanceCreate
    def initialize(services_event_repository, logger)
      @services_event_repository = services_event_repository
      @logger = logger
    end

    def create(request_attrs, accepts_incomplete)
      request_params = request_attrs.except('parameters')
      arbitrary_params = request_attrs['parameters']

      service_instance = ManagedServiceInstance.new(request_params)

      client = VCAP::Services::ServiceClientProvider.provide({ instance: service_instance })

      broker_response = client.provision(
        service_instance,
        accepts_incomplete: accepts_incomplete,
        arbitrary_parameters: arbitrary_params,
        maintenance_info: service_instance.service_plan.maintenance_info
      )

      service_instance_attributes = broker_response[:instance].merge({ maintenance_info: service_instance.service_plan.maintenance_info })

      begin
        service_instance.save_with_new_operation(service_instance_attributes, broker_response[:last_operation])
      rescue StandardError => e
        cleanup_instance_without_db(e, service_instance)
      end

      setup_async_job(request_attrs, service_instance) if service_instance.operation_in_progress?

      if !accepts_incomplete || service_instance.last_operation.state != 'in progress'
        @services_event_repository.record_service_instance_event(:create, service_instance,
                                                                 request_attrs)
      end

      service_instance
    end

    def setup_async_job(request_attrs, service_instance)
      job = VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
        'service-instance-state-fetch',
        service_instance.guid,
        @services_event_repository.user_audit_info,
        request_attrs
      )
      enqueuer = Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic)
      enqueuer.enqueue
      @services_event_repository.record_service_instance_event(:start_create, service_instance, request_attrs)
    end

    def cleanup_instance_without_db(e, service_instance, message: 'Failed to save while creating service instance')
      @logger.error "#{message} #{service_instance.guid} with exception: #{e}."
      service_resource_cleanup = DatabaseErrorServiceResourceCleanup.new(@logger)
      service_resource_cleanup.attempt_deprovision_instance(service_instance)
      raise e
    end
  end
end
