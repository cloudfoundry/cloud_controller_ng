module Fog
  module Google
    class Compute
      class InstanceTemplate < Fog::Model
        identity :name

        attribute :kind
        attribute :self_link, :aliases => "selfLink"
        attribute :description
        # Properties is a hash describing the templates
        # A minimal example is
        # :properties => {
        #   :machine_type => TEST_MACHINE_TYPE,
        #   :disks => [{
        #     :boot => true,
        #     :initialize_params => {
        #       :source_image => "projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20180522"}
        #     }],
        #     :network_interfaces => [{
        #       :network => "global/networks/default"
        #     }]
        #   }
        # }
        # @see https://cloud.google.com/compute/docs/reference/rest/v1/instanceTemplates/insert
        attribute :properties

        def save
          requires :name
          requires :properties

          data = service.insert_instance_template(name, properties, description)
          operation = Fog::Google::Compute::Operations.new(:service => service).get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :name
          data = service.delete_instance_template(name)
          operation = Fog::Google::Compute::Operations.new(:service => service).get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end
      end
    end
  end
end
