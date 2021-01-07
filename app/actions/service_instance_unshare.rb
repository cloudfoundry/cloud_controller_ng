require 'actions/service_credential_binding_delete'
require 'actions/mixins/bindings_delete'

module VCAP::CloudController
  class ServiceInstanceUnshare
    include V3::BindingsDeleteMixin

    class Error < ::StandardError
    end

    def unshare(service_instance, target_space, user_audit_info)
      errors = delete_bindings_in_target_space!(service_instance, target_space, user_audit_info)
      if errors.any?
        error!("Unshare of service instance failed because one or more bindings could not be deleted.\n\n " \
          "#{errors.map { |err| "\t#{err.message}" }.join("\n\n")}"
        )
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
      delete_bindings(bindings_in_target_space, user_audit_info: user_audit_info)
    end

    def unbinding_operation_in_progress!(binding)
      raise Error.new("The binding between an application and service instance #{binding.service_instance.name} " \
                                   "in space #{binding.app.space.name} is being deleted asynchronously.")
    end
  end
end
