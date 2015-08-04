require 'actions/services/synchronous_orphan_mitigate'

module VCAP::CloudController
  class InvalidDashboardInfo < StandardError; end
  class ServiceInstanceCreate
    def initialize(services_event_repository, logger)
      @services_event_repository = services_event_repository
      @logger = logger
    end

    def create(request_attrs, accepts_incomplete)
      request_params = request_attrs.except('parameters')
      arbitrary_params = request_attrs['parameters']

      service_instance = ManagedServiceInstance.new(request_params)

      broker_response = service_instance.client.provision(
        service_instance,
        accepts_incomplete: accepts_incomplete,
        arbitrary_parameters: arbitrary_params
      )

      begin
        service_instance.save_with_new_operation(broker_response[:instance], broker_response[:last_operation])
      rescue => e
        mitigate_orphan(e, service_instance)
      end

      if service_instance.operation_in_progress?
        setup_async_job(request_attrs, service_instance)
      end

      dashboard_client_info = broker_response[:dashboard_client]

      if dashboard_client_info
        setup_dashboard(broker_response, dashboard_client_info, service_instance)
      end

      if !accepts_incomplete || service_instance.last_operation.state != 'in progress'
        @services_event_repository.record_service_instance_event(:create, service_instance, request_attrs)
      end

      service_instance
    end

    def setup_dashboard(broker_response, dashboard_client_info, service_instance)
      if !broker_response[:instance].key?(:dashboard_url) || broker_response[:instance][:dashboard_url].nil?
        error_message = 'Missing dashboard_url from broker response while creating a service instance with dashboard_client'
        e = VCAP::Errors::ApiError.new_from_details('ServiceDashboardClientMissingUrl', error_message)
        mitigate_orphan(e, service_instance, message: error_message)
      end
      client_manager = VCAP::Services::SSO::DashboardClientManager.new(
        service_instance,
        @services_event_repository,
        VCAP::CloudController::ServiceInstanceDashboardClient
      )
      client_manager.add_client_for_instance(dashboard_client_info)
    end

    def setup_async_job(request_attrs, service_instance)
      job = VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
        'service-instance-state-fetch',
        service_instance.client.attrs,
        service_instance.guid,
        @services_event_repository,
        request_attrs,
      )
      enqueuer = Jobs::Enqueuer.new(job, queue: 'cc-generic')
      enqueuer.enqueue
    end

    def mitigate_orphan(e, service_instance, message: 'Failed to save while creating service instance')
      @logger.error "#{message} #{service_instance.guid} with exception: #{e}."
      orphan_mitigator = SynchronousOrphanMitigate.new(@logger)
      orphan_mitigator.attempt_deprovision_instance(service_instance)
      raise e
    end
  end
end
