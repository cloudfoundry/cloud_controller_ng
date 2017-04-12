require 'actions/services/service_instance_delete'

module VCAP::CloudController
  class SpaceDelete
    def initialize(user_audit_info, services_event_repository)
      @user_audit_info = user_audit_info
      @services_event_repository = services_event_repository
    end

    def delete(dataset)
      dataset.all.inject([]) do |errors, space_model|
        instance_delete_errors = delete_service_instances(space_model)
        unless instance_delete_errors.empty?
          error_message = instance_delete_errors.map { |error| "\t#{error.message}" }.join("\n\n")
          errors.push CloudController::Errors::ApiError.new_from_details('SpaceDeletionFailed', space_model.name, error_message)
        end

        broker_delete_errors = delete_service_brokers(space_model)
        unless broker_delete_errors.empty?
          error_message = broker_delete_errors.map { |error| "\t#{error.message}" }.join("\n\n")
          errors.push CloudController::Errors::ApiError.new_from_details('SpaceDeletionFailed', space_model.name, error_message)
        end

        if instance_delete_errors.empty?
          delete_apps(space_model)
          space_model.destroy
        end

        errors
      end
    end

    def timeout_error(dataset)
      space_name = dataset.first.name
      CloudController::Errors::ApiError.new_from_details('SpaceDeleteTimeout', space_name)
    end

    private

    def service_broker_remover(services_event_repository)
      VCAP::Services::ServiceBrokers::ServiceBrokerRemover.new(services_event_repository)
    end

    def delete_service_instances(space_model)
      service_instance_deleter = ServiceInstanceDelete.new(
        accepts_incomplete: true,
        multipart_delete: true,
        event_repository: @services_event_repository
      )
      service_instance_deleter.delete(space_model.service_instances_dataset)
    end

    def delete_apps(space_model)
      AppDelete.new(@user_audit_info).delete(space_model.app_models)
    end

    def delete_service_brokers(space_model)
      broker_remover = service_broker_remover(@services_event_repository)
      private_service_brokers = space_model.service_brokers
      deletable_brokers = private_service_brokers.reject { |broker| broker.service_plans.map(&:service_instances).flatten.any? }

      deletable_brokers.each do |broker|
        broker_remover.remove(broker)
      end

      errors_accumulator = []
      brokers_with_remaining_instances = private_service_brokers - deletable_brokers
      brokers_with_remaining_instances.each do |broker|
        errors_accumulator.push CloudController::Errors::ApiError.new_from_details('ServiceBrokerNotRemovable', broker.name)
      end
      errors_accumulator
    end
  end
end
