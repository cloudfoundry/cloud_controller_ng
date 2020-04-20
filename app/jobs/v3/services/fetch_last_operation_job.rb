require 'jobs/v2/services/asynchronous_operations'
require 'jobs/cc_job'

module VCAP::CloudController
  module V3
    class FetchLastOperationJob < VCAP::CloudController::Jobs::CCJob
      include VCAP::CloudController::Jobs::Services::AsynchronousOperations

      attr_accessor :service_instance_guid, :request_attrs, :poll_interval, :end_timestamp

      def initialize(service_instance_guid:, request_attrs:, end_timestamp: nil, pollable_job_guid:, user_audit_info:)
        @service_instance_guid = service_instance_guid
        @request_attrs = request_attrs
        @end_timestamp = end_timestamp || new_end_timestamp
        @pollable_job_guid = pollable_job_guid
        @user_audit_info = user_audit_info
        update_polling_interval
      end

      def success(_)
        service_instance = ManagedServiceInstance.first(guid: service_instance_guid)

        if service_instance.terminal_state?
          pollable_job.update(state: PollableJobModel::COMPLETE_STATE)
        else
          try_again
        end
      end

      def error(job, exception)
        wrapper = VCAP::CloudController::Jobs::PollableJobWrapper.new(job)
        wrapper.failure(job)
        wrapper.error(job, exception)
      end

      def perform
        service_instance = ManagedServiceInstance.first(guid: service_instance_guid)
        gone! if service_instance.nil?

        intended_operation = service_instance.last_operation
        aborted! if intended_operation.type != 'create'

        client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)

        last_operation_result = client.fetch_service_instance_last_operation(service_instance)
        update_with_attributes(last_operation_result[:last_operation], service_instance, intended_operation)

        if last_operation_result[:last_operation][:state] == 'failed'
          operation_failed!(last_operation_result[:last_operation][:description])
        end

        @retry_after = last_operation_result[:retry_after]
      rescue HttpRequestError, HttpResponseError, Sequel::Error => e
        logger = Steno.logger('cc-background')
        logger.error("There was an error while fetching the service instance operation state: #{e}")
        @retry_after = nil
        try_again
      end

      def max_attempts
        1
      end

      private

      def gone!
        raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', @service_instance_guid)
      end

      def aborted!
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'Create', 'delete in progress')
      end

      def operation_failed!(msg)
        raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceProvisionFailed', msg)
      end

      def repository
        Repositories::ServiceEventRepository.new(@user_audit_info)
      end

      def pollable_job
        PollableJobModel.where(guid: @pollable_job_guid)
      end

      def try_again
        delayed_job = retry_job(retry_after_header: @retry_interval)
        pollable_job.update(
          state: PollableJobModel::POLLING_STATE,
          delayed_job_guid: delayed_job.guid
        )
      end

      def record_event(service_instance, request_attrs)
        type = service_instance.last_operation.type
        repository.record_service_instance_event(type, service_instance, request_attrs)
      end

      def update_with_attributes(last_operation, service_instance, intended_operation)
        ServiceInstance.db.transaction do
          service_instance.lock!
          return unless intended_operation == service_instance.last_operation

          service_instance.save_and_update_operation(
            last_operation: last_operation.slice(:state, :description)
          )

          if service_instance.last_operation.state == 'succeeded'
            apply_proposed_changes(service_instance)
            record_event(service_instance, @request_attrs)
          end
        end
      end

      def end_timestamp_reached
        ManagedServiceInstance.first(guid: service_instance_guid).save_and_update_operation(
          last_operation: {
            state: 'failed',
            description: 'Service Broker failed to provision within the required time.',
          }
        )
        raise CloudController::Errors::ApiError.new_from_details('JobTimeout')
      end

      def apply_proposed_changes(service_instance)
        if service_instance.last_operation.type == 'delete'
          service_instance.last_operation.destroy
          service_instance.destroy
        else
          service_instance.save_and_update_operation(service_instance.last_operation.proposed_changes)
        end
      end

      def service_plan
        ManagedServiceInstance.first(guid: service_instance_guid).try(:service_plan)
      rescue Sequel::Error => e
        Steno.logger('cc-background').error("There was an error while fetching the service instance: #{e}")
        nil
      end
    end

    class ServiceInstanceGoneError < StandardError
    end
  end
end
