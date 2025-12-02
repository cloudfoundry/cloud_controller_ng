module Fog
  module Google
    class Compute
      class Mock
        def add_backend_service_backends(_backend_service, _new_backends)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def add_backend_service_backends(backend_service, _new_backends)
          @compute.patch_backend_service(@project, backend_service.name, backend_service)
        end
      end
    end
  end
end
