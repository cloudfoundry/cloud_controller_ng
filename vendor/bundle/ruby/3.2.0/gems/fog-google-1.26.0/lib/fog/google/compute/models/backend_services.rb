module Fog
  module Google
    class Compute
      class BackendServices < Fog::Collection
        model Fog::Google::Compute::BackendService

        def all(_filters = {})
          data = service.list_backend_services.items || []
          load(data.map(&:to_h))
        end

        def get(identity)
          if identity
            backend_service = service.get_backend_service(identity).to_h
            return new(backend_service)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
