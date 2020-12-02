require 'jobs/v3/create_service_route_binding_job_actor'
require 'jobs/v3/create_service_credential_binding_job_actor'
require 'jobs/v3/create_service_key_binding_job_actor'
require 'actions/service_credential_binding_app_create'
require 'actions/service_credential_binding_key_create'
require 'actions/service_route_binding_create'

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
        when :key
          CreateServiceKeyBindingJobActor.new
        else
          raise InvalidType
        end
      end

      def self.action(type, user_audit_info, audit_hash)
        case type
        when :route
          V3::ServiceRouteBindingCreate.new(user_audit_info, audit_hash)
        when :credential
          V3::ServiceCredentialBindingAppCreate.new(user_audit_info, audit_hash)
        when :key
          V3::ServiceCredentialBindingKeyCreate.new(user_audit_info, audit_hash)
        else
          raise InvalidType
        end
      end
    end
  end
end
