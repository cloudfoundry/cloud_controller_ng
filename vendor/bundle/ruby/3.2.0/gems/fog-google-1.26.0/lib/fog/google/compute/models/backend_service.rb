module Fog
  module Google
    class Compute
      class BackendService < Fog::Model
        identity :name

        attribute :backends
        attribute :creation_timestamp
        attribute :description
        attribute :fingerprint
        attribute :health_checks, :aliases => "healthChecks"
        attribute :id
        attribute :kind
        attribute :port
        attribute :protocol
        attribute :self_link, :aliases => "selfLink"
        attribute :timeout_sec, :aliases => "timeoutSec"

        def save
          requires :name, :health_checks

          options = {
            :description => description,
            :backends => backends,
            :fingerprint => fingerprint,
            :health_checks => health_checks,
            :port => port,
            :protocol => protocol,
            :timeout_sec => timeout_sec
          }

          data = service.insert_backend_service(name, **options)
          operation = Fog::Google::Compute::Operations.new(:service => service).get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :name

          data = service.delete_backend_service(name)
          operation = Fog::Google::Compute::Operations.new(:service => service).get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end

        def get_health
          service.get_backend_service_health(self)
        end

        def add_backend(backend)
          # ensure backend is an array of hashes
          backend = [backend] unless backend.class == Array
          backend.map! { |resource| resource.class == String ? { "group" => resource } : resource }
          service.add_backend_service_backends(self, backend)
          reload
        end

        def ready?
          service.get_backend_service(name)
          true
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          false
        end

        def reload
          requires :name

          return unless data =
                          begin
                            collection.get(name)
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
