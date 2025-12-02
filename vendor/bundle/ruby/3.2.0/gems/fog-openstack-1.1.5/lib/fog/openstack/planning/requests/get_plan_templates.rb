module Fog
  module OpenStack
    class Planning
      class Real
        def get_plan_templates(plan_uuid)
          request(
            :expects => [200, 204],
            :method  => 'GET',
            :path    => "plans/#{plan_uuid}/templates"
          )
        end
      end

      class Mock
        def get_plan_templates(_plan_uuid)
          response = Excon::Response.new
          response.status = [200, 204][rand(2)]
          response.body = {
            "environment.yaml"        => "... content of template file ...",
            "plan.yaml"               => "... content of template file ...",
            "provider-compute-1.yaml" => "... content of template file ..."
          }
          response
        end
      end
    end
  end
end
