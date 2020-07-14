require 'jobs/v3/service_instance_async_job'

module VCAP::CloudController
  module V3
    class CreateServiceInstanceJob < ServiceInstanceAsyncJob
      def initialize(service_instance_guid, arbitrary_parameters: {}, user_audit_info:)
        super(service_instance_guid, user_audit_info)
        @request_attr = arbitrary_parameters
      end

      def operation
        :provision
      end

      def operation_type
        'create'
      end

      def send_broker_request(client)
        client.provision(
          service_instance,
          accepts_incomplete: true,
          arbitrary_parameters: @request_attr,
          maintenance_info: service_instance.service_plan.maintenance_info
        )
      end
    end
  end
end
