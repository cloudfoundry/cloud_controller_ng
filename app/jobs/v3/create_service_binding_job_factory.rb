require 'jobs/v3/create_service_route_binding_job_actor'
require 'jobs/v3/create_service_credential_binding_job_actor'

module VCAP::CloudController
  module V3
    class CreateServiceBindingFactory
      class InvalidType < StandardError
      end

      def self.for(type)
        case type
        when :route
          CreateServiceRouteBindingJobActor.new
        when :credential
          CreateServiceCredentialBindingJobActor.new
        else
          raise InvalidType
        end
      end

      def self.action(type, user_audit_info, audit_hash)
        case type
        when :route
          service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(user_audit_info)
          V3::ServiceRouteBindingCreate.new(service_event_repository)
        when :credential
          V3::ServiceCredentialBindingCreate.new(user_audit_info, audit_hash)
        else
          raise InvalidType
        end
      end
    end
  end
end
