require 'jobs/queues'
require 'jobs/enqueuer'
require 'jobs/generic_enqueuer'
require 'jobs/v3/delete_binding_job'
require 'jobs/v3/delete_service_binding_job_factory'

module VCAP::CloudController
  module V3
    module BindingsDeleteMixin
      private

      def delete_bindings(bindings, user_audit_info:)
        type = nil
        binding_delete_action = nil

        bindings.each_with_object([]) do |binding, errors|
          type ||= DeleteServiceBindingFactory.type_of(binding)
          binding_delete_action ||= DeleteServiceBindingFactory.action(type, user_audit_info)

          result = binding_delete_action.delete(binding)
          unless result[:finished]
            polling_job = DeleteBindingJob.new(type, binding.guid, user_audit_info:)
            Jobs::GenericEnqueuer.shared.enqueue_pollable(polling_job)
            unbinding_operation_in_progress!(binding)
          end
        rescue StandardError => e
          errors << e
        end
      end
    end
  end
end
