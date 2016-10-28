## Generated from desired_lrp_requests.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class DesiredLRPLifecycleResponse
        include Beefcake::Message
      end

      class DesiredLRPsResponse
        include Beefcake::Message
      end

      class DesiredLRPsRequest
        include Beefcake::Message
      end

      class DesiredLRPResponse
        include Beefcake::Message
      end

      class DesiredLRPSchedulingInfosResponse
        include Beefcake::Message
      end

      class DesiredLRPByProcessGuidRequest
        include Beefcake::Message
      end

      class DesireLRPRequest
        include Beefcake::Message
      end

      class UpdateDesiredLRPRequest
        include Beefcake::Message
      end

      class RemoveDesiredLRPRequest
        include Beefcake::Message
      end

      class DesiredLRPLifecycleResponse
        optional :error, Error, 1
      end

      class DesiredLRPsResponse
        optional :error, Error, 1
        repeated :desired_lrps, DesiredLRP, 2
      end

      class DesiredLRPsRequest
        optional :domain, :string, 1
      end

      class DesiredLRPResponse
        optional :error, Error, 1
        optional :desired_lrp, DesiredLRP, 2
      end

      class DesiredLRPSchedulingInfosResponse
        optional :error, Error, 1
        repeated :desired_lrp_scheduling_infos, DesiredLRPSchedulingInfo, 2
      end

      class DesiredLRPByProcessGuidRequest
        optional :process_guid, :string, 1
      end

      class DesireLRPRequest
        optional :desired_lrp, DesiredLRP, 1
      end

      class UpdateDesiredLRPRequest
        optional :process_guid, :string, 1
        optional :update, DesiredLRPUpdate, 2
      end

      class RemoveDesiredLRPRequest
        optional :process_guid, :string, 1
      end
    end
  end
end
