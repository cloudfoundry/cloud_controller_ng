require 'actions/v3/service_instance_delete'
require 'jobs/v3/delete_service_instance_job'
require 'repositories/service_account_event_repository'

module VCAP::CloudController
  class SpaceDelete
    def initialize(user_audit_info, services_event_repository)
      @user_audit_info = user_audit_info
      @services_event_repository = services_event_repository
    end

    def delete(dataset)
      dataset.each_with_object([]) do |space_model, errors|
        instance_delete_errors = delete_service_instances(space_model)
        err = accumulate_space_deletion_error(instance_delete_errors, space_model.name)
        errors << err unless err.nil?

        broker_delete_errors = delete_service_brokers(space_model)
        err = accumulate_space_deletion_error(broker_delete_errors, space_model.name)
        errors << err unless err.nil?

        instance_unshare_errors = unshare_service_instances(space_model)
        err = accumulate_space_deletion_error(instance_unshare_errors, space_model.name)
        errors << err unless err.nil?

        next unless instance_delete_errors.empty? && instance_unshare_errors.empty?

        account_delete_errors = delete_service_accounts(space_model)
        err = accumulate_space_deletion_error(account_delete_errors, space_model.name)
        errors << err unless err.nil?
        next unless account_delete_errors.empty?

        Space.db.transaction do
          delete_apps(space_model)
          space_model.destroy
          Repositories::SpaceEventRepository.new.record_space_delete_request(space_model, @user_audit_info, true)
        end
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
      return if operation_errors.empty?

      error_message = operation_errors.map { |error| "\t#{error.message}" }.join("\n\n")
      CloudController::Errors::ApiError.new_from_details('SpaceDeletionFailed', space_name, error_message)
    end

    def delete_service_instances(space_model)
      space_model.service_instances_dataset.each_with_object([]) do |service_instance, errors|
        service_instance_deleter = V3::ServiceInstanceDelete.new(service_instance, @services_event_repository)
        result = service_instance_deleter.delete
        unless result[:finished]
          polling_job = V3::DeleteServiceInstanceJob.new(service_instance.guid, @services_event_repository.user_audit_info)
          Jobs::GenericEnqueuer.shared.enqueue_pollable(polling_job)
          errors << CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name)
        end
      rescue StandardError => e
        errors << e
      end
    end

    def unshare_service_instances(space_model)
      unshare = ServiceInstanceUnshare.new
      errors = []
      space_model.service_instances_shared_from_other_spaces.each do |service_instance|
        unshare.unshare(service_instance, space_model, @user_audit_info)
      rescue StandardError => e
        errors.push(e)
      end
      errors
    end

    def delete_apps(space_model)
      AppDelete.new(@user_audit_info).delete(space_model.app_models_dataset.all)
    end

    def delete_service_accounts(space_model)
      accounts = ServiceAccountModel.where(space_guid: space_model.guid).order(:guid).all
      return [] if accounts.empty?

      ServiceAccountModel.db.transaction do
        accounts.each do |account|
          account.lock!
          if PollableJobModel.where(resource_guid: account.guid, resource_type: 'service_account', state: %w[PROCESSING POLLING]).any?
            raise ServiceAccountProvision::Conflict.new('service account operation is already in progress')
          end

          account.update(enabled: false, status: 'deleting')
        end
      end

      # AppDelete removes service bindings, tasks and process snapshots. Do not
      # roll this back if later UAA cleanup fails: retries must see real progress.
      delete_apps(space_model)
      provisioner = CloudController::DependencyLocator.instance.service_account_provisioner
      accounts.each_with_object([]) do |account, errors|
        Repositories::ServiceAccountEventRepository.record(account, 'delete', @user_audit_info, { recursive: true })
        provisioner.deprovision(account, delete: true)
      rescue StandardError => e
        errors << e
      end
    rescue StandardError => e
      [e]
    end

    def delete_service_brokers(space_model)
      broker_remover = service_broker_remover(@services_event_repository)
      private_service_brokers = space_model.service_brokers
      deletable_brokers = private_service_brokers.reject do |broker|
        ServiceInstance.
          join(:service_plans, id: :service_instances__service_plan_id).
          join(:services, id: :service_plans__service_id).
          where(services__service_broker_id: broker.id).
          any?
      end

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
