module Fog
  module Google
    class Compute
      class Mock
        def list_backend_services
          backend_services = data[:backend_services].values

          build_excon_response("kind" => "compute#backendServiceList",
                               "selfLink" => "https://www.googleapis.com/compute/#{api_version}/projects/#{@project}/global/backendServices",
                               "id" => "projects/#{@project}/global/backendServices",
                               "items" => backend_services)
        end
      end

      class Real
        def list_backend_services
          @compute.list_backend_services(@project)
        end
      end
    end
  end
end
