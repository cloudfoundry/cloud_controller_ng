## Generated from events.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class ActualLRPCreatedEvent
        include Beefcake::Message
      end

      class ActualLRPChangedEvent
        include Beefcake::Message
      end

      class ActualLRPRemovedEvent
        include Beefcake::Message
      end

      class DesiredLRPCreatedEvent
        include Beefcake::Message
      end

      class DesiredLRPChangedEvent
        include Beefcake::Message
      end

      class DesiredLRPRemovedEvent
        include Beefcake::Message
      end

      class ActualLRPCrashedEvent
        include Beefcake::Message
      end

      class ActualLRPCreatedEvent
        optional :actual_lrp_group, ActualLRPGroup, 1
      end

      class ActualLRPChangedEvent
        optional :before, ActualLRPGroup, 1
        optional :after, ActualLRPGroup, 2
      end

      class ActualLRPRemovedEvent
        optional :actual_lrp_group, ActualLRPGroup, 1
      end

      class DesiredLRPCreatedEvent
        optional :desired_lrp, DesiredLRP, 1
      end

      class DesiredLRPChangedEvent
        optional :before, DesiredLRP, 1
        optional :after, DesiredLRP, 2
      end

      class DesiredLRPRemovedEvent
        optional :desired_lrp, DesiredLRP, 1
      end

      class ActualLRPCrashedEvent
        optional :actual_lrp_key, ActualLRPKey, 1
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 2
        optional :crash_count, :int32, 3
        optional :crash_reason, :string, 4
        optional :since, :int64, 5
      end
    end
  end
end
