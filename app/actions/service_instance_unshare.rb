module VCAP::CloudController
  class ServiceInstanceUnshare
    class Error < ::StandardError
    end

    def unshare(service_instance, target_space, user_audit_info)
      errors, _ = delete_bindings_in_target_space!(service_instance, target_space, user_audit_info)
      if errors.any?
        error_msg = "Unshare of service instance failed because one or more bindings could not be deleted.\n\n " \
          "#{errors.map { |err| "\t#{err.message}" }.join("\n\n")}"
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

      delete_errors, warnings = ServiceBindingDelete.new(user_audit_info, true).delete(bindings_in_target_space)
      return [delete_errors, warnings] unless delete_errors.empty?

      bindings_in_target_space.select(&:operation_in_progress?).each do |binding_in_progress|
        delete_errors << Error.new("The binding between an application and service instance #{service_instance.name} " \
                                   "in space #{target_space.name} is being deleted asynchronously.")
      end

      [delete_errors, warnings]
    end
  end
end
