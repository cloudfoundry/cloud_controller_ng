module Fog
  module OpenStack
    class Image
      class V2
        class Real
          def add_member_to_image(image_id, tenant_id)
            request(
              :expects => [200],
              :method  => 'POST',
              :path    => "images/#{image_id}/members",
              :body    => Fog::JSON.encode(:member => tenant_id)
            )
          end
        end

        class Mock
          def add_member_to_image(_image_id, _tenant_id)
            response = Excon::Response.new
            response.status = 200
            response
          end
        end
      end
    end
  end
end
