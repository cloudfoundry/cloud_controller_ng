module Fog
  module Google
    class Compute
      class TargetHttpProxy < Fog::Model
        identity :name

        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description, :aliases => "description"
        attribute :id, :aliases => "id"
        attribute :kind, :aliases => "kind"
        attribute :self_link, :aliases => "selfLink"
        attribute :url_map, :aliases => "urlMap"

        def save
          requires :identity
          data = service.insert_target_http_proxy(
            identity, :description => description, :url_map => url_map
          )
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :identity

          data = service.delete_target_http_proxy(identity)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end

        def set_url_map(url_map, async = true)
          requires :identity

          data = service.set_target_http_proxy_url_map(identity, url_map)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          reload
        end

        def ready?
          requires :identity

          service.get_target_http_proxy(identity)
          true
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          false
        end

        def reload
          requires :identity

          return unless data = begin
            collection.get(identity)
          rescue Excon::Errors::SocketError
            nil
          end

          new_attributes = data.attributes
          merge_attributes(new_attributes)
          self
        end

        RUNNING_STATE = "READY".freeze
      end
    end
  end
end
