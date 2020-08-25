module VCAP::CloudController
  module V3
    class CreateRouteBindingJob < VCAP::CloudController::Jobs::CCJob
      def initialize(precursor_guid, parameters:, user_audit_info:)
        @precursor_guid = precursor_guid
        @user_audit_info = user_audit_info
        @parameters = parameters
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
        'service_route_bindings.create'
      end

      def resource_guid
        @precursor_guid
      end

      def resource_type
        'service_route_binding'
      end

      def perform
        precursor = RouteBinding.first(guid: @precursor_guid)
        service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(@user_audit_info)
        action = V3::ServiceRouteBindingCreate.new(service_event_repository)
        action.bind(precursor, parameters: @parameters)
      end
    end
  end
end
