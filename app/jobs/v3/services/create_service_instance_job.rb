require 'jobs/v3/services/fetch_last_operation_job'

module VCAP::CloudController
  module V3
    class CreateServiceInstanceJob < VCAP::CloudController::Jobs::CCJob
      def initialize(service_instance_guid, arbitrary_parameters: {}, user_audit_info:)
        @service_instance_guid = service_instance_guid
        @arbitrary_parameters = arbitrary_parameters
        @user_audit_info = user_audit_info
      end

      def perform
        client = VCAP::Services::ServiceClientProvider.provide({ instance: service_instance })

        begin
          broker_response = client.provision(
            service_instance,
              accepts_incomplete: true,
              arbitrary_parameters: arbitrary_parameters,
              maintenance_info: service_instance.service_plan.maintenance_info
          )
        rescue => e
          service_instance.save_with_new_operation({}, {
              type: 'create',
              state: 'failed',
              description: e.message,
          })
          raise e
        end

        service_instance.save_with_new_operation(broker_response[:instance], broker_response[:last_operation])
      end

      def success(job)
        pollable_job = PollableJobModel.first(delayed_job_guid: job.guid)
        if service_instance.operation_in_progress?
          polling_job = VCAP::CloudController::V3::FetchLastOperationJob.new(
            service_instance_guid: service_instance.guid,
            pollable_job_guid: pollable_job.guid,
            request_attrs: @arbitrary_parameters,
            user_audit_info: @user_audit_info,
          )
          enqueuer = Jobs::Enqueuer.new(polling_job, queue: Jobs::Queues.generic)
          delayed_job = enqueuer.enqueue

          pollable_job.update(
            state: PollableJobModel::POLLING_STATE,
            delayed_job_guid: delayed_job.guid
          )
        else
          pollable_job.update(state: PollableJobModel::COMPLETE_STATE)
          record_event(service_instance, @arbitrary_parameters)
        end
      end

      def job_name_in_configuration
        :service_instance_create
      end

      def max_attempts
        1
      end

      def resource_type
        'service_instances'
      end

      def resource_guid
        service_instance_guid
      end

      def display_name
        'service_instance.create'
      end

      private

      def repository
        Repositories::ServiceEventRepository.new(@user_audit_info)
      end

      def record_event(service_instance, request_attrs)
        repository.record_service_instance_event(:create, service_instance, request_attrs)
      end

      def service_instance
        @service_instance ||= ManagedServiceInstance.first(guid: service_instance_guid)
      end

      attr_reader :service_instance_guid, :arbitrary_parameters
    end
  end
end
