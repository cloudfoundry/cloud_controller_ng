module Fog
  module OpenStack
    class Identity
      class V2
        class Real
          def list_endpoints_for_token(token_id)
            request(
              :expects => [200, 203],
              :method  => 'HEAD',
              :path    => "tokens/#{token_id}/endpoints"
            )
          end
        end

        class Mock
        end
      end
    end
  end
end
