module Fog
  module OpenStack
    class Network
      class Real
        def list_networks(filters = {})
          request(
            :expects => 200,
            :method  => 'GET',
            :path    => 'networks',
            :query   => filters
          )
        end
      end

      class Mock
        def list_networks(_filters = {})
          Excon::Response.new(
            :body   => {'networks' => data[:networks].values},
            :status => 200
          )
        end
      end
    end
  end
end
