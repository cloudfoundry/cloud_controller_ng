module Fog
  module Google
    class Compute
      ##
      # Represents a Project resource
      #
      # @see https://developers.google.com/compute/docs/reference/latest/projects
      class Project < Fog::Model
        identity :name

        attribute :kind
        attribute :id
        attribute :common_instance_metadata, :aliases => "commonInstanceMetadata"
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description
        attribute :quotas
        attribute :self_link, :aliases => "selfLink"

        def set_metadata(metadata = {})
          requires :identity

          operation = service.set_common_instance_metadata(identity, common_instance_metadata["fingerprint"], metadata)
          Fog::Google::Compute::Operations.new(:service => service).get(operation.id)
        end
      end
    end
  end
end
