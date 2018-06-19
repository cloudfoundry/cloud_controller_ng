require 'actions/services/service_instance_delete'

module VCAP::CloudController
  class SpaceDelete
    def initialize(user_audit_info, services_event_repository, space_roles_deleter)
      @user_audit_info = user_audit_info
      @services_event_repository = services_event_repository
      @space_roles_deleter = space_roles_deleter
    end

    def delete(dataset)
      dataset.inject([]) do |errors, space_model|
        instance_delete_errors = delete_service_instances(space_model)
        err = accumulate_space_deletion_error(instance_delete_errors, space_model.name)
        errors << err unless err.nil?

        broker_delete_errors = delete_service_brokers(space_model)
        err = accumulate_space_deletion_error(broker_delete_errors, space_model.name)
        errors << err unless err.nil?

        instance_unshare_errors = unshare_service_instances(space_model)
        err = accumulate_space_deletion_error(instance_unshare_errors, space_model.name)
        errors << err unless err.nil?

        if instance_delete_errors.empty? && instance_unshare_errors.empty?
          delete_apps(space_model)
          space_model.destroy
        end

        role_delete_errors = delete_roles(space_model)
        err = accumulate_space_deletion_error(role_delete_errors, space_model.name)
        errors << err unless err.nil?

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

    def accumulate_space_deletion_error(operation_errors, space_name)
      unless operation_errors.empty?
        error_message = operation_errors.map { |error| "\t#{error.message}" }.join("\n\n")
        CloudController::Errors::ApiError.new_from_details('SpaceDeletionFailed', space_name, error_message)
      end
    end

    def delete_service_instances(space_model)
      service_instance_deleter = ServiceInstanceDelete.new(
        accepts_incomplete: true,
        event_repository: @services_event_repository
      )

      delete_instance_errors, _ = service_instance_deleter.delete(space_model.service_instances_dataset)
      if delete_instance_errors.empty?
        async_deprovisioning_instances = space_model.service_instances_dataset.all.select(&:operation_in_progress?)
        deprovision_in_progress_errors = async_deprovisioning_instances.map do |service_instance|
          CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name)
        end

        delete_instance_errors.concat deprovision_in_progress_errors
      end

      delete_instance_errors
    end

    def unshare_service_instances(space_model)
      unshare = ServiceInstanceUnshare.new
      errors = []
      space_model.service_instances_shared_from_other_spaces.each do |service_instance|
        begin
          unshare.unshare(service_instance, space_model, @user_audit_info)
        rescue => e
          errors.push(e)
        end
      end
      errors
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

    def delete_roles(space_model)
      @space_roles_deleter.delete(space_model)
    end
  end
end
