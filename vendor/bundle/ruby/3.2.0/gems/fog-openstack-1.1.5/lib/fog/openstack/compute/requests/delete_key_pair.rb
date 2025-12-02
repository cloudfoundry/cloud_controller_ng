module Fog
  module OpenStack
    class Compute
      class Real
        def delete_key_pair(key_name, user_id = nil)
          options = {}
          options[:user_id] = user_id unless user_id.nil?
          request(
            :expects => [202, 204],
            :method  => 'DELETE',
            :path    => "os-keypairs/#{Fog::OpenStack.escape(key_name)}"
          )
        end
      end

      class Mock
        def delete_key_pair(_key_name)
          response = Excon::Response.new
          response.status = 202
          response.headers = {
            "Content-Type"   => "text/html; charset=UTF-8",
            "Content-Length" => "0",
            "Date"           => Date.new
          }
          response.body = {}
          response
        end
      end
    end
  end
end
