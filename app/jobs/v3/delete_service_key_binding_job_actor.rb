module VCAP::CloudController
  module V3
    class DeleteServiceKeyBindingJobActor
      def display_name
        'service_keys.delete'
      end

      def resource_type
        'service_credential_binding'
      end

      def get_resource(resource_id)
        ServiceKey.first(guid: resource_id)
      end
    end
  end
end
