require 'jobs/v3/services/service_broker_catalog_updater'

module VCAP::CloudController
  module V3
    class CreateServiceInstanceJob < VCAP::CloudController::Jobs::CCJob
      def initialize(service_instance_guid, arbitrary_parameters: {})
        @service_instance_guid = service_instance_guid
        @arbitrary_parameters = arbitrary_parameters
      end

      def perform
        service_instance = ManagedServiceInstance.last(guid: service_instance_guid)
        client = VCAP::Services::ServiceClientProvider.provide({ instance: service_instance })

        begin
          broker_response = client.provision(
            service_instance,
            accepts_incomplete: false,
            arbitrary_parameters: arbitrary_parameters,
            maintenance_info: service_instance.service_plan.maintenance_info
          )
        rescue => e
          service_instance.save_with_new_operation({}, {
            type: 'create',
            state: 'failed',
            description: e.message,
          })
          raise e
        end

        service_instance.save_with_new_operation(broker_response[:instance], broker_response[:last_operation])
      end

      def job_name_in_configuration
        :service_instance_create
      end

      def max_attempts
        1
      end

      def resource_type
        'service_instances'
      end

      def resource_guid
        service_instance_guid
      end

      def display_name
        'service_instance.create'
      end

      private

      attr_reader :service_instance_guid, :arbitrary_parameters
    end
  end
end
