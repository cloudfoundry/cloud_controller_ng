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
      class ActualLRPLifecycleResponse < ::Protobuf::Message; end
      class ActualLRPGroupsResponse < ::Protobuf::Message; end
      class ActualLRPGroupResponse < ::Protobuf::Message; end
      class ActualLRPGroupsRequest < ::Protobuf::Message; end
      class ActualLRPGroupsByProcessGuidRequest < ::Protobuf::Message; end
      class ActualLRPGroupByProcessGuidAndIndexRequest < ::Protobuf::Message; end
      class ClaimActualLRPRequest < ::Protobuf::Message; end
      class StartActualLRPRequest < ::Protobuf::Message; end
      class CrashActualLRPRequest < ::Protobuf::Message; end
      class FailActualLRPRequest < ::Protobuf::Message; end
      class RetireActualLRPRequest < ::Protobuf::Message; end
      class RemoveActualLRPRequest < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class ActualLRPLifecycleResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
      end

      class ActualLRPGroupsResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        repeated ::Diego::Bbs::Models::ActualLRPGroup, :actual_lrp_groups, 2
      end

      class ActualLRPGroupResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        optional ::Diego::Bbs::Models::ActualLRPGroup, :actual_lrp_group, 2
      end

      class ActualLRPGroupsRequest
        optional :string, :domain, 1
        optional :string, :cell_id, 2
      end

      class ActualLRPGroupsByProcessGuidRequest
        optional :string, :process_guid, 1
      end

      class ActualLRPGroupByProcessGuidAndIndexRequest
        optional :string, :process_guid, 1
        optional :int32, :index, 2
      end

      class ClaimActualLRPRequest
        optional :string, :process_guid, 1
        optional :int32, :index, 2
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 3
      end

      class StartActualLRPRequest
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2
        optional ::Diego::Bbs::Models::ActualLRPNetInfo, :actual_lrp_net_info, 3
      end

      class CrashActualLRPRequest
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2
        optional :string, :error_message, 3
      end

      class FailActualLRPRequest
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional :string, :error_message, 2
      end

      class RetireActualLRPRequest
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
      end

      class RemoveActualLRPRequest
        optional :string, :process_guid, 1
        optional :int32, :index, 2
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 3
      end

    end

  end

end

