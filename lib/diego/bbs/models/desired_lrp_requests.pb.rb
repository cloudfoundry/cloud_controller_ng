# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'
require 'desired_lrp.pb'
require 'error.pb'

module Diego
  module Bbs
    module Models

      ##
      # Message Classes
      #
      class DesiredLRPLifecycleResponse < ::Protobuf::Message; end
      class DesiredLRPsResponse < ::Protobuf::Message; end
      class DesiredLRPsRequest < ::Protobuf::Message; end
      class DesiredLRPResponse < ::Protobuf::Message; end
      class DesiredLRPSchedulingInfosResponse < ::Protobuf::Message; end
      class DesiredLRPByProcessGuidRequest < ::Protobuf::Message; end
      class DesireLRPRequest < ::Protobuf::Message; end
      class UpdateDesiredLRPRequest < ::Protobuf::Message; end
      class RemoveDesiredLRPRequest < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class DesiredLRPLifecycleResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
      end

      class DesiredLRPsResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        repeated ::Diego::Bbs::Models::DesiredLRP, :desired_lrps, 2
      end

      class DesiredLRPsRequest
        optional :string, :domain, 1
        repeated :string, :process_guids, 2
      end

      class DesiredLRPResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        optional ::Diego::Bbs::Models::DesiredLRP, :desired_lrp, 2
      end

      class DesiredLRPSchedulingInfosResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        repeated ::Diego::Bbs::Models::DesiredLRPSchedulingInfo, :desired_lrp_scheduling_infos, 2
      end

      class DesiredLRPByProcessGuidRequest
        optional :string, :process_guid, 1
      end

      class DesireLRPRequest
        optional ::Diego::Bbs::Models::DesiredLRP, :desired_lrp, 1
      end

      class UpdateDesiredLRPRequest
        optional :string, :process_guid, 1
        optional ::Diego::Bbs::Models::DesiredLRPUpdate, :update, 2
      end

      class RemoveDesiredLRPRequest
        optional :string, :process_guid, 1
      end

    end

  end

end

