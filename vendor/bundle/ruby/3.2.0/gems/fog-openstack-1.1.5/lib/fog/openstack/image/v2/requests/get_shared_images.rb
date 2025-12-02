module Fog
  module OpenStack
    class Image
      class V2
        class Real
          def get_shared_images(tenant_id)
            request(
              :expects => [200, 204],
              :method  => 'GET',
              :path    => "shared-images/#{tenant_id}"
            )
          end
        end

        class Mock
          def get_shared_images(_tenant_id)
            response = Excon::Response.new
            response.status = [200, 204][rand(2)]
            response.body = {
              "shared_images" => [
                {"image_id"  => "ff528b20431645ebb5fa4b0a71ca002f",
                 "can_share" => false}
              ]
            }
            response
          end
        end
      end
    end
  end
end
