module Fog
  module OpenStack
    class Introspection
      class Real
        def delete_rules_all
          request(
            :expects => 204,
            :method  => "DELETE",
            :path    => "rules"
          )
        end
      end

      class Mock
        def delete_rules_all
          response = Excon::Response.new
          response.status = 204
          response
        end
      end
    end
  end
end
