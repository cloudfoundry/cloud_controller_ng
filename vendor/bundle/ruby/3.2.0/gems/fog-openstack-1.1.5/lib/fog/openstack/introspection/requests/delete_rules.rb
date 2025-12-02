module Fog
  module OpenStack
    class Introspection
      class Real
        def delete_rules(rule_id)
          request(
            :expects => 204,
            :method  => "DELETE",
            :path    => "rules/#{rule_id}"
          )
        end
      end

      class Mock
        def delete_rules(_rule_id)
          response = Excon::Response.new
          response.status = 204
          response
        end
      end
    end
  end
end
