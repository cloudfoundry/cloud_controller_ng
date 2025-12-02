module Fog
  module Google
    class Compute
      class Mock
        def insert_instance_template(_name, _properties, _description)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        ##
        # Create a new template.
        #
        # @param name [String]
        #   Name to assign to the created template. Must be unique.
        # @param descrption [String]
        #   Optional description of the template
        # @param properties [Hash]
        #   Template attributes. You can use any of the options documented at
        #   https://cloud.google.com/compute/docs/reference/rest/v1/instanceTemplates/insert
        # @see https://cloud.google.com/compute/docs/reference/rest/v1/instanceTemplates/insert
        # @return [::Google::Apis::ComputeV1::Operation]
        #   response object that represents the insertion operation.
        def insert_instance_template(name, properties, description)
          instance_template = ::Google::Apis::ComputeV1::InstanceTemplate.new(
            description: description,
            name: name,
            properties: properties,
          )

          @compute.insert_instance_template(@project, instance_template)
        end
      end
    end
  end
end
