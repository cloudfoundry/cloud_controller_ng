require 'repositories/service_instance_share_event_repository'
require 'jobs/v3/services/create_service_instance_job'
require 'actions/mixins/service_instance_create'

module VCAP::CloudController
  class ServiceInstanceCreateManaged
    include ServiceInstanceCreateMixin

    class InvalidManagedServiceInstance < ::StandardError
    end

    def initialize(service_event_repository)
      @service_event_repository = service_event_repository
    end

    def create(message)
      service_plan = ServicePlan.first(guid: message.service_plan_guid)
      raise InvalidManagedServiceInstance.new('Service plan not found.') unless service_plan

      attr = {
        name: message.name,
        space_guid: message.space_guid,
        tags: message.tags,
        service_plan: service_plan,
        maintenance_info: service_plan.maintenance_info
      }

      last_operation = {
        type: 'create',
        state: ManagedServiceInstance::IN_PROGRESS_STRING
      }

      pollable_job = nil
      ManagedServiceInstance.db.transaction do
        instance = ManagedServiceInstance.new
        instance.save_with_new_operation(attr, last_operation)
        MetadataUpdate.update(instance, message)

        service_event_repository.record_service_instance_event(:start_create, instance, message.audit_hash)

        creation_job = V3::CreateServiceInstanceJob.new(instance.guid, arbitrary_parameters: message.parameters)
        pollable_job = Jobs::Enqueuer.new(creation_job, queue: Jobs::Queues.generic).enqueue_pollable
      end

      pollable_job
    rescue Sequel::ValidationFailed => e
      validation_error!(e, name: message.name)
    end

    private

    def error!(message)
      raise InvalidManagedServiceInstance.new(message)
    end

    attr_reader :service_event_repository
  end
end
