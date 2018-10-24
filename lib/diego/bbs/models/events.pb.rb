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
require 'desired_lrp.pb'
require 'task.pb'
require 'modification_tag.pb'

module Diego
  module Bbs
    module Models

      ##
      # Message Classes
      #
      class ActualLRPCreatedEvent < ::Protobuf::Message; end
      class ActualLRPChangedEvent < ::Protobuf::Message; end
      class ActualLRPRemovedEvent < ::Protobuf::Message; end
      class ActualLRPInstanceCreatedEvent < ::Protobuf::Message; end
      class ActualLRPInfo < ::Protobuf::Message; end
      class ActualLRPInstanceChangedEvent < ::Protobuf::Message; end
      class ActualLRPInstanceRemovedEvent < ::Protobuf::Message; end
      class DesiredLRPCreatedEvent < ::Protobuf::Message; end
      class DesiredLRPChangedEvent < ::Protobuf::Message; end
      class DesiredLRPRemovedEvent < ::Protobuf::Message; end
      class ActualLRPCrashedEvent < ::Protobuf::Message; end
      class EventsByCellId < ::Protobuf::Message; end
      class TaskCreatedEvent < ::Protobuf::Message; end
      class TaskChangedEvent < ::Protobuf::Message; end
      class TaskRemovedEvent < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class ActualLRPCreatedEvent
        optional ::Diego::Bbs::Models::ActualLRPGroup, :actual_lrp_group, 1
      end

      class ActualLRPChangedEvent
        optional ::Diego::Bbs::Models::ActualLRPGroup, :before, 1
        optional ::Diego::Bbs::Models::ActualLRPGroup, :after, 2
      end

      class ActualLRPRemovedEvent
        optional ::Diego::Bbs::Models::ActualLRPGroup, :actual_lrp_group, 1
      end

      class ActualLRPInstanceCreatedEvent
        optional ::Diego::Bbs::Models::ActualLRP, :actual_lrp, 1
      end

      class ActualLRPInfo
        optional ::Diego::Bbs::Models::ActualLRPNetInfo, :actual_lrp_net_info, 3
        optional :int32, :crash_count, 4
        optional :string, :crash_reason, 5
        optional :string, :state, 6
        optional :string, :placement_error, 7
        optional :int64, :since, 8
        optional ::Diego::Bbs::Models::ModificationTag, :modification_tag, 9
        optional ::Diego::Bbs::Models::ActualLRP::Presence, :presence, 10
      end

      class ActualLRPInstanceChangedEvent
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2
        optional ::Diego::Bbs::Models::ActualLRPInfo, :before, 3
        optional ::Diego::Bbs::Models::ActualLRPInfo, :after, 4
      end

      class ActualLRPInstanceRemovedEvent
        optional ::Diego::Bbs::Models::ActualLRP, :actual_lrp, 1
      end

      class DesiredLRPCreatedEvent
        optional ::Diego::Bbs::Models::DesiredLRP, :desired_lrp, 1
      end

      class DesiredLRPChangedEvent
        optional ::Diego::Bbs::Models::DesiredLRP, :before, 1
        optional ::Diego::Bbs::Models::DesiredLRP, :after, 2
      end

      class DesiredLRPRemovedEvent
        optional ::Diego::Bbs::Models::DesiredLRP, :desired_lrp, 1
      end

      class ActualLRPCrashedEvent
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2
        optional :int32, :crash_count, 3
        optional :string, :crash_reason, 4
        optional :int64, :since, 5
      end

      class EventsByCellId
        optional :string, :cell_id, 1
      end

      class TaskCreatedEvent
        optional ::Diego::Bbs::Models::Task, :task, 1
      end

      class TaskChangedEvent
        optional ::Diego::Bbs::Models::Task, :before, 1
        optional ::Diego::Bbs::Models::Task, :after, 2
      end

      class TaskRemovedEvent
        optional ::Diego::Bbs::Models::Task, :task, 1
      end

    end

  end

end

