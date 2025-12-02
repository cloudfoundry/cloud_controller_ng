module Fog
  module Google
    class Compute
      ##
      # Represents a Subnetwork resource
      #
      # @see https://developers.google.com/compute/docs/reference/latest/subnetworks
      class Subnetwork < Fog::Model
        identity :name

        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description
        attribute :gateway_address, :aliases => "gatewayAddress"
        attribute :id
        attribute :ip_cidr_range, :aliases => "ipCidrRange"
        attribute :kind
        attribute :network
        attribute :private_ip_google_access, :aliases => "privateIpGoogleAccess"
        attribute :region
        attribute :secondary_ip_ranges, :aliases => "secondaryIpRanges"
        attribute :self_link, :aliases => "selfLink"

        def save
          requires :identity, :network, :region, :ip_cidr_range

          data = service.insert_subnetwork(identity, region, network, ip_cidr_range, attributes)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name, nil, data.region)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :identity, :region

          data = service.delete_subnetwork(identity, region)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name, nil, data.region)
          operation.wait_for { ready? } unless async
          operation
        end

        def update_interface_config(network_interface)
          network_interface["subnetwork"] = self_link if network_interface
          network_interface
        end

        def expand_ip_cidr_range(range, async = true)
          requires :identity, :region

          data = service.expand_subnetwork_ip_cidr_range(
            identity, region, range
          )
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name, nil, data.region)
          operation.wait_for { ready? } unless async
          reload
        end

        def set_private_ip_google_access(access, async = true)
          requires :identity, :region

          data = service.set_subnetwork_private_ip_google_access(
            identity, region, access
          )
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name, nil, data.region)

          operation.wait_for { ready? } unless async
          reload
        end

        def reload
          requires :identity, :region

          data = collection.get(identity, region.split("/")[-1])
          merge_attributes(data.attributes)
          self
        end
      end
    end
  end
end
