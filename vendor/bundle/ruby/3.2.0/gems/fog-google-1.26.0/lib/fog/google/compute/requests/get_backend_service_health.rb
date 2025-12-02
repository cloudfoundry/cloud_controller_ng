module Fog
  module Google
    class Compute
      class Mock
        def get_backend_service_health(_backend_service)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_backend_service_health(backend_service)
          health_results = backend_service.backends.map do |backend|
            group = ::Google::Apis::ComputeV1::ResourceGroupReference.new(group: backend[:group])
            resp = @compute.get_backend_service_health(@project, backend_service.name, group)
            [backend[:group], resp.health_status]
          end
          Hash[health_results]
        end
      end
    end
  end
end
