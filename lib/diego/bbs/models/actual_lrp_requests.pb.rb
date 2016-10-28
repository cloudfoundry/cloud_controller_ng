## Generated from actual_lrp_requests.proto for models
require "beefcake"

require_relative 'error.pb'

module Diego
  module Bbs
    module Models

      class ActualLRPLifecycleResponse
        include Beefcake::Message
      end

      class ActualLRPGroupsResponse
        include Beefcake::Message
      end

      class ActualLRPGroupResponse
        include Beefcake::Message
      end

      class ActualLRPGroupsRequest
        include Beefcake::Message
      end

      class ActualLRPGroupsByProcessGuidRequest
        include Beefcake::Message
      end

      class ActualLRPGroupByProcessGuidAndIndexRequest
        include Beefcake::Message
      end

      class ClaimActualLRPRequest
        include Beefcake::Message
      end

      class StartActualLRPRequest
        include Beefcake::Message
      end

      class CrashActualLRPRequest
        include Beefcake::Message
      end

      class FailActualLRPRequest
        include Beefcake::Message
      end

      class RetireActualLRPRequest
        include Beefcake::Message
      end

      class RemoveActualLRPRequest
        include Beefcake::Message
      end

      class ActualLRPLifecycleResponse
        optional :error, Error, 1
      end

      class ActualLRPGroupsResponse
        optional :error, Error, 1
        repeated :actual_lrp_groups, ActualLRPGroup, 2
      end

      class ActualLRPGroupResponse
        optional :error, Error, 1
        optional :actual_lrp_group, ActualLRPGroup, 2
      end

      class ActualLRPGroupsRequest
        optional :domain, :string, 1
        optional :cell_id, :string, 2
      end

      class ActualLRPGroupsByProcessGuidRequest
        optional :process_guid, :string, 1
      end

      class ActualLRPGroupByProcessGuidAndIndexRequest
        optional :process_guid, :string, 1
        optional :index, :int32, 2
      end

      class ClaimActualLRPRequest
        optional :process_guid, :string, 1
        optional :index, :int32, 2
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 3
      end

      class StartActualLRPRequest
        optional :actual_lrp_key, ActualLRPKey, 1
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 2
        optional :actual_lrp_net_info, ActualLRPNetInfo, 3
      end

      class CrashActualLRPRequest
        optional :actual_lrp_key, ActualLRPKey, 1
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 2
        optional :error_message, :string, 3
      end

      class FailActualLRPRequest
        optional :actual_lrp_key, ActualLRPKey, 1
        optional :error_message, :string, 2
      end

      class RetireActualLRPRequest
        optional :actual_lrp_key, ActualLRPKey, 1
      end

      class RemoveActualLRPRequest
        optional :process_guid, :string, 1
        optional :index, :int32, 2
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 3
      end
    end
  end
end
