## Generated from evacuation.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class EvacuationResponse
        include Beefcake::Message
      end

      class EvacuateClaimedActualLRPRequest
        include Beefcake::Message
      end

      class EvacuateRunningActualLRPRequest
        include Beefcake::Message
      end

      class EvacuateStoppedActualLRPRequest
        include Beefcake::Message
      end

      class EvacuateCrashedActualLRPRequest
        include Beefcake::Message
      end

      class RemoveEvacuatingActualLRPRequest
        include Beefcake::Message
      end

      class RemoveEvacuatingActualLRPResponse
        include Beefcake::Message
      end

      class EvacuationResponse
        optional :error, Error, 1
        optional :keep_container, :bool, 2
      end

      class EvacuateClaimedActualLRPRequest
        optional :actual_lrp_key, ActualLRPKey, 1
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 2
      end

      class EvacuateRunningActualLRPRequest
        optional :actual_lrp_key, ActualLRPKey, 1
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 2
        optional :actual_lrp_net_info, ActualLRPNetInfo, 3
        optional :ttl, :uint64, 4
      end

      class EvacuateStoppedActualLRPRequest
        optional :actual_lrp_key, ActualLRPKey, 1
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 2
      end

      class EvacuateCrashedActualLRPRequest
        optional :actual_lrp_key, ActualLRPKey, 1
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 2
        optional :error_message, :string, 3
      end

      class RemoveEvacuatingActualLRPRequest
        optional :actual_lrp_key, ActualLRPKey, 1
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 2
      end

      class RemoveEvacuatingActualLRPResponse
        optional :error, Error, 1
      end
    end
  end
end
