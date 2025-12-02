module Fog
  module OpenStack
    class Identity
      class V2
        class Real
          def update_tenant(id, attributes)
            request(
              :expects => [200],
              :method  => 'PUT',
              :path    => "tenants/#{id}",
              :body    => Fog::JSON.encode('tenant' => attributes)
            )
          end
        end

        class Mock
          def update_tenant(_id, attributes)
            response = Excon::Response.new
            response.status = [200, 204][rand(2)]
            attributes = {'enabled' => true, 'id' => '1'}.merge(attributes)
            response.body = {
              'tenant' => attributes
            }
            response
          end
        end
      end
    end
  end
end
