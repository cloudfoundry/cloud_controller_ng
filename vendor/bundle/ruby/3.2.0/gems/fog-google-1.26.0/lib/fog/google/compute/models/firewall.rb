module Fog
  module Google
    class Compute
      ##
      # Represents a Firewall resource
      #
      # @see https://developers.google.com/compute/docs/reference/latest/firewalls
      class Firewall < Fog::Model
        identity :name

        # Allowed ports in API format
        #
        # @example
        # [
        #   { :ip_protocol => "TCP",
        #     :ports => ["201"] }
        # ]
        # @return [Array<Hash>]
        attribute :allowed
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        # Denied ports in API format
        #
        # @example
        # [
        #   { :ip_protocol => "TCP",
        #     :ports => ["201"] }
        # ]
        # @return [Array<Hash>]
        attribute :denied
        attribute :description
        attribute :destination_ranges, :aliases => "destinationRanges"
        attribute :direction
        attribute :id
        attribute :kind
        attribute :network
        attribute :priority
        attribute :self_link, :aliases => "selfLink"
        attribute :source_ranges, :aliases => "sourceRanges"
        attribute :source_service_accounts, :aliases => "sourceServiceAccounts"
        attribute :source_tags, :aliases => "sourceTags"
        attribute :target_service_accounts, :aliases => "targetServiceAccounts"
        attribute :target_tags, :aliases => "targetTags"

        def save
          requires :identity

          unless self.allowed || self.denied
            raise Fog::Errors::Error.new("Firewall needs denied or allowed ports specified")
          end

          id.nil? ? create : update
        end

        def create
          data = service.insert_firewall(identity, attributes)
          operation = Fog::Google::Compute::Operations.new(service: service)
                                                      .get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def update
          requires :identity, :allowed, :network

          data = service.update_firewall(identity, attributes)
          operation = Fog::Google::Compute::Operations.new(service: service)
                                                      .get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def patch(diff = {})
          requires :identity

          data = service.patch_firewall(identity, diff)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :identity

          data = service.delete_firewall(identity)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end
      end
    end
  end
end
