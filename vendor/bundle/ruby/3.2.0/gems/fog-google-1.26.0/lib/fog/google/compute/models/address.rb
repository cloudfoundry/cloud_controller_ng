module Fog
  module Google
    class Compute
      ##
      # Represents an Address resource
      #
      # @see https://developers.google.com/compute/docs/reference/latest/addresses
      class Address < Fog::Model
        identity :name

        attribute :kind
        attribute :id
        attribute :address
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description
        attribute :region
        attribute :self_link, :aliases => "selfLink"
        attribute :status
        attribute :users

        IN_USE_STATE   = "IN_USE".freeze
        RESERVED_STATE = "RESERVED".freeze
        RESERVING_STATE = "RESERVING".freeze

        def server
          return nil if !in_use? || users.nil? || users.empty?

          service.servers.get(users.first.split("/")[-1])
        end

        def server=(server)
          requires :identity, :region
          server ? associate(server) : disassociate
        end

        def save
          requires :identity, :region

          data = service.insert_address(identity, region, attributes)
          operation = Fog::Google::Compute::Operations
                      .new(service: service)
                      .get(data.name, nil, data.region)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :identity, :region

          data = service.delete_address(identity, region.split("/")[-1])
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, nil, data.region)

          operation.wait_for { ready? } unless async
          operation
        end

        def reload
          requires :identity, :region

          data = collection.get(identity, region.split("/")[-1])
          merge_attributes(data.attributes)
          self
        end

        def in_use?
          status == IN_USE_STATE
        end

        def ready?
          status != RESERVING_STATE
        end

        private

        # Associates the ip address to a given server
        #
        # @param [String]  server - GCE instance name
        # @param [String]  nic_name - NIC interface name, defaults to GCE
        #                             standard primary nic - "nic0"
        # @param [Boolean]  async - whether to run the operation asynchronously
        #
        # @return [Fog::Google::Compute::Operation]
        def associate(server, nic_name = "nic0", async = false)
          requires :address

          data = service.add_server_access_config(
            server.name, server.zone, nic_name, :nat_ip => address
          )
          operation = Fog::Google::Compute::Operations
                      .new(:service => service)
                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
        end

        # Disassociates the ip address from a resource it's attached to
        #
        # @param [Boolean]  async - whether to run the operation asynchronously
        #
        # @return [Fog::Google::Compute::Operation]
        def disassociate(async = false)
          requires :address

          return nil if !in_use? || users.nil? || users.empty?

          server_name = users.first.split("/")[-1]

          # An address can only be associated with one server at a time
          server = service.servers.get(server_name)
          server.network_interfaces.each do |nic|
            # Skip if nic has no access_config
            next if nic[:access_configs].nil? || nic[:access_configs].empty?

            access_config = nic[:access_configs].first

            # Skip access_config with different address
            next if access_config[:nat_ip] != address

            data = service.delete_server_access_config(
              server.name, server.zone, nic[:name], access_config[:name]
            )
            operation = Fog::Google::Compute::Operations
                        .new(:service => service)
                        .get(data.name, data.zone)
            operation.wait_for { ready? } unless async
            return operation
          end
        end
      end
    end
  end
end
