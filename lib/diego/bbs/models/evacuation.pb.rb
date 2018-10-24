# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'
require 'actual_lrp.pb'
require 'error.pb'

module Diego
  module Bbs
    module Models

      ##
      # Message Classes
      #
      class EvacuationResponse < ::Protobuf::Message; end
      class EvacuateClaimedActualLRPRequest < ::Protobuf::Message; end
      class EvacuateRunningActualLRPRequest < ::Protobuf::Message; end
      class EvacuateStoppedActualLRPRequest < ::Protobuf::Message; end
      class EvacuateCrashedActualLRPRequest < ::Protobuf::Message; end
      class RemoveEvacuatingActualLRPRequest < ::Protobuf::Message; end
      class RemoveEvacuatingActualLRPResponse < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class EvacuationResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        optional :bool, :keep_container, 2
      end

      class EvacuateClaimedActualLRPRequest
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2
      end

      class EvacuateRunningActualLRPRequest
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2
        optional ::Diego::Bbs::Models::ActualLRPNetInfo, :actual_lrp_net_info, 3
        optional :uint64, :ttl, 4
      end

      class EvacuateStoppedActualLRPRequest
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2
      end

      class EvacuateCrashedActualLRPRequest
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2
        optional :string, :error_message, 3
      end

      class RemoveEvacuatingActualLRPRequest
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2
      end

      class RemoveEvacuatingActualLRPResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
      end

    end

  end

end

