module Fog
  module Google
    class Compute
      class GlobalForwardingRule < Fog::Model
        identity :name

        attribute :ip_address, :aliases => "IPAddress"
        attribute :ip_protocol, :aliases => "IPProtocol"
        attribute :backend_service, :aliases => "backendService"
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description
        attribute :id
        attribute :ip_version, :aliases => "ipVersion"
        attribute :kind
        attribute :load_balancing_scheme, :aliases => "loadBalancingScheme"
        attribute :network
        attribute :port_range, :aliases => "portRange"
        attribute :ports
        attribute :region
        attribute :self_link, :aliases => "selfLink"
        attribute :subnetwork
        attribute :target

        def save
          requires :identity

          data = service.insert_global_forwarding_rule(identity, attributes)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name, nil, data.region)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :identity
          data = service.delete_global_forwarding_rule(identity)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name, nil, data.region)
          operation.wait_for { ready? } unless async
          operation
        end

        def set_target(new_target)
          requires :identity

          new_target = new_target.self_link unless new_target.class == String
          self.target = new_target
          service.set_global_forwarding_rule_target(
            identity, :target => new_target
          )
          reload
        end

        def ready?
          service.get_global_forwarding_rule(name)
          true
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          false
        end

        def reload
          requires :name

          return unless data = begin
            collection.get(name)
          rescue Excon::Errors::SocketError
            nil
          end

          new_attributes = data.attributes
          merge_attributes(new_attributes)
          self
        end
      end
    end
  end
end
