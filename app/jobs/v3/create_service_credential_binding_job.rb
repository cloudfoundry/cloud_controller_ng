require 'jobs/reoccurring_job'
require 'actions/v3/service_binding_create'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class CreateServiceCredentialBindingJob < Jobs::ReoccurringJob
      def initialize(binding_guid, parameters:, user_audit_info:, audit_hash:)
        super()
        @binding_guid = binding_guid
        @user_audit_info = user_audit_info
        @parameters = parameters
        @audit_hash = audit_hash
        @first_time = true
      end

      def operation
        :bind
      end

      def operation_type
        'create'
      end

      def max_attempts
        1
      end

      def display_name
        'service_bindings.create'
      end

      def resource_guid
        @binding_guid
      end

      def resource_type
        'service_credential_binding'
      end

      def perform
        binding = ServiceBinding.first(guid: @binding_guid)
        gone! unless binding

        action = V3::ServiceBindingCreate.new(binding_guid: @binding_guid, user_audit_info: @user_audit_info, audit_hash: @audit_hash)

        if @first_time
          @first_time = false
          action.bind(binding.service_instance, parameters: @parameters, accepts_incomplete: false)
          return finish if binding.reload.terminal_state?
        end

        binding.save_with_new_operation({
          type: 'create',
          state: 'failed',
          description: 'async bindings are not supported'
        })
        finish
      rescue => e
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'bind', e.message)
      end

      private

      def gone!
        raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', "The binding could not be found: #{@binding_guid}")
      end
    end
  end
end
