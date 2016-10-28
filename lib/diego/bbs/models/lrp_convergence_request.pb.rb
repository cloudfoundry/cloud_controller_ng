## Generated from lrp_convergence_request.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class ConvergeLRPsResponse
        include Beefcake::Message
      end

      class ConvergeLRPsResponse
        optional :error, Error, 1
      end
    end
  end
end
