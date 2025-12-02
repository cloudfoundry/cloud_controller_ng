module Fog
  module OpenStack
    class Planning
      class Real
        def delete_plan(plan_uuid)
          request(
            :expects => [204],
            :method  => 'DELETE',
            :path    => "plans/#{plan_uuid}"
          )
        end
      end

      class Mock
        def delete_plan(_plan_uuid)
          response = Excon::Response.new
          response.status = 204
          response
        end
      end
    end
  end
end
