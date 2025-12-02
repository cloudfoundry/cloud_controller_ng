module Fog
  module OpenStack
    class Introspection
      class Real
        def abort_introspection(node_id)
          request(
            :body    => "",
            :expects => 202,
            :method  => "POST",
            :path    => "introspection/#{node_id}/abort"
          )
        end
      end

      class Mock
        def abort_introspection(_node_id)
          response = Excon::Response.new
          response.status = 202
          response.body = ""
          response
        end
      end
    end
  end
end
