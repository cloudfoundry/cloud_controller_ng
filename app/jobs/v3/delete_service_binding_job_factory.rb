require 'jobs/v3/delete_service_route_binding_job_actor'
require 'jobs/v3/delete_service_credential_binding_job_actor'

module VCAP::CloudController
  module V3
    class DeleteServiceBindingFactory
      class InvalidType < StandardError
      end

      def self.for(type)
        case type
        when :route
          DeleteServiceRouteBindingJobActor.new
        when :credential
          DeleteServiceCredentialBindingJobActor.new
        else
          raise InvalidType
        end
      end

      def self.action(type, user_audit_info)
        case type
        when :route
          service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(user_audit_info)
          V3::ServiceRouteBindingDelete.new(service_event_repository)
        when :credential
          raise InvalidType
          # V3::ServiceCredentialBindingCreate.new(user_audit_info, audit_hash)
        else
          raise InvalidType
        end
      end
    end
  end
end
