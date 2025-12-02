module Fog
  module Google
    class Compute
      ##
      # Represents an Address resource
      #
      # @see https://developers.google.com/compute/docs/reference/latest/addresses
      class GlobalAddress < Fog::Model
        identity :name

        attribute :address
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description
        attribute :id
        attribute :ip_version, :aliases => "ipVersion"
        attribute :kind
        attribute :self_link, :aliases => "selfLink"
        attribute :status
        attribute :users

        IN_USE_STATE   = "IN_USE".freeze
        RESERVED_STATE = "RESERVED".freeze

        def save
          requires :identity

          data = service.insert_global_address(identity, attributes)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :identity

          data = service.delete_global_address(identity)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end

        def reload
          requires :identity

          data = collection.get(identity)
          merge_attributes(data.attributes)
          self
        end

        def in_use?
          status == IN_USE_STATE
        end
      end
    end
  end
end
