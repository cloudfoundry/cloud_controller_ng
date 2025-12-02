module Fog
  module Google
    class Compute
      class Mock
        def get_backend_service(service_name)
          backend_service = data[:backend_services][service_name]
          return nil if backend_service.nil?
          build_excon_response(backend_service)
        end
      end

      class Real
        def get_backend_service(service_name)
          @compute.get_backend_service(@project, service_name)
        end
      end
    end
  end
end
