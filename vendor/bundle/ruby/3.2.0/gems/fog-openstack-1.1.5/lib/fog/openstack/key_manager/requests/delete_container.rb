module Fog
  module OpenStack
    class KeyManager
      class Real
        def delete_container(id)
          request(
            :expects => [204],
            :method  => 'DELETE',
            :path    => "containers/#{id}"
          )
        end
      end

      class Mock
      end
    end
  end
end
