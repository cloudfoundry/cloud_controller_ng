# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: events.proto

require 'google/protobuf'

require 'actual_lrp_pb'
require 'desired_lrp_pb'
require 'task_pb'
require 'modification_tag_pb'
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "diego.bbs.models.ActualLRPCreatedEvent" do
    optional :actual_lrp_group, :message, 1, "diego.bbs.models.ActualLRPGroup"
  end
  add_message "diego.bbs.models.ActualLRPChangedEvent" do
    optional :before, :message, 1, "diego.bbs.models.ActualLRPGroup"
    optional :after, :message, 2, "diego.bbs.models.ActualLRPGroup"
  end
  add_message "diego.bbs.models.ActualLRPRemovedEvent" do
    optional :actual_lrp_group, :message, 1, "diego.bbs.models.ActualLRPGroup"
  end
  add_message "diego.bbs.models.ActualLRPInstanceCreatedEvent" do
    optional :actual_lrp, :message, 1, "diego.bbs.models.ActualLRP"
    optional :trace_id, :string, 2
  end
  add_message "diego.bbs.models.ActualLRPInfo" do
    optional :actual_lrp_net_info, :message, 3, "diego.bbs.models.ActualLRPNetInfo"
    optional :crash_count, :int32, 4
    optional :crash_reason, :string, 5
    optional :state, :string, 6
    optional :placement_error, :string, 7
    optional :since, :int64, 8
    optional :modification_tag, :message, 9, "diego.bbs.models.ModificationTag"
    optional :presence, :enum, 10, "diego.bbs.models.ActualLRP.Presence"
    optional :availability_zone, :string, 12
    oneof :optional_routable do
      optional :Routable, :bool, 11
    end
  end
  add_message "diego.bbs.models.ActualLRPInstanceChangedEvent" do
    optional :actual_lrp_key, :message, 1, "diego.bbs.models.ActualLRPKey"
    optional :actual_lrp_instance_key, :message, 2, "diego.bbs.models.ActualLRPInstanceKey"
    optional :before, :message, 3, "diego.bbs.models.ActualLRPInfo"
    optional :after, :message, 4, "diego.bbs.models.ActualLRPInfo"
    optional :trace_id, :string, 5
  end
  add_message "diego.bbs.models.ActualLRPInstanceRemovedEvent" do
    optional :actual_lrp, :message, 1, "diego.bbs.models.ActualLRP"
    optional :trace_id, :string, 2
  end
  add_message "diego.bbs.models.DesiredLRPCreatedEvent" do
    optional :desired_lrp, :message, 1, "diego.bbs.models.DesiredLRP"
    optional :trace_id, :string, 2
  end
  add_message "diego.bbs.models.DesiredLRPChangedEvent" do
    optional :before, :message, 1, "diego.bbs.models.DesiredLRP"
    optional :after, :message, 2, "diego.bbs.models.DesiredLRP"
    optional :trace_id, :string, 3
  end
  add_message "diego.bbs.models.DesiredLRPRemovedEvent" do
    optional :desired_lrp, :message, 1, "diego.bbs.models.DesiredLRP"
    optional :trace_id, :string, 2
  end
  add_message "diego.bbs.models.ActualLRPCrashedEvent" do
    optional :actual_lrp_key, :message, 1, "diego.bbs.models.ActualLRPKey"
    optional :actual_lrp_instance_key, :message, 2, "diego.bbs.models.ActualLRPInstanceKey"
    optional :crash_count, :int32, 3
    optional :crash_reason, :string, 4
    optional :since, :int64, 5
  end
  add_message "diego.bbs.models.EventsByCellId" do
    optional :cell_id, :string, 1
  end
  add_message "diego.bbs.models.TaskCreatedEvent" do
    optional :task, :message, 1, "diego.bbs.models.Task"
  end
  add_message "diego.bbs.models.TaskChangedEvent" do
    optional :before, :message, 1, "diego.bbs.models.Task"
    optional :after, :message, 2, "diego.bbs.models.Task"
  end
  add_message "diego.bbs.models.TaskRemovedEvent" do
    optional :task, :message, 1, "diego.bbs.models.Task"
  end
end

module Diego
  module Bbs
    module Models
      ActualLRPCreatedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.ActualLRPCreatedEvent").msgclass
      ActualLRPChangedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.ActualLRPChangedEvent").msgclass
      ActualLRPRemovedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.ActualLRPRemovedEvent").msgclass
      ActualLRPInstanceCreatedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.ActualLRPInstanceCreatedEvent").msgclass
      ActualLRPInfo = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.ActualLRPInfo").msgclass
      ActualLRPInstanceChangedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.ActualLRPInstanceChangedEvent").msgclass
      ActualLRPInstanceRemovedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.ActualLRPInstanceRemovedEvent").msgclass
      DesiredLRPCreatedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesiredLRPCreatedEvent").msgclass
      DesiredLRPChangedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesiredLRPChangedEvent").msgclass
      DesiredLRPRemovedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesiredLRPRemovedEvent").msgclass
      ActualLRPCrashedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.ActualLRPCrashedEvent").msgclass
      EventsByCellId = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.EventsByCellId").msgclass
      TaskCreatedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.TaskCreatedEvent").msgclass
      TaskChangedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.TaskChangedEvent").msgclass
      TaskRemovedEvent = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.TaskRemovedEvent").msgclass
    end
  end
end
