## Generated from ping.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class PingResponse
        include Beefcake::Message
      end

      class PingResponse
        optional :available, :bool, 1
      end
    end
  end
end
