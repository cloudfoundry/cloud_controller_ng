module VCAP::CloudController
  class ServiceInstanceUnshare
    class Error < ::StandardError
    end

    def unshare(service_instance, target_space, user_audit_info)
      errors, _ = delete_bindings_in_target_space!(service_instance, target_space, user_audit_info)
      if errors.any?
        error_msg = "Unshare of service instance failed because one or more bindings could not be deleted.\n\n#{errors}"
        error!(error_msg)
      end

      service_instance.remove_shared_space(target_space)

      Repositories::ServiceInstanceShareEventRepository.record_unshare_event(
        service_instance, target_space.guid, user_audit_info)
    end

    private

    def error!(message)
      raise Error.new(message)
    end

    def delete_bindings_in_target_space!(service_instance, target_space, user_audit_info)
      active_bindings = ServiceBinding.where(service_instance_guid: service_instance.guid)
      bindings_in_target_space = active_bindings.all.select { |b| b.app.space_guid == target_space.guid }

      ServiceBindingDelete.new(user_audit_info).delete(bindings_in_target_space)
    end
  end
end
