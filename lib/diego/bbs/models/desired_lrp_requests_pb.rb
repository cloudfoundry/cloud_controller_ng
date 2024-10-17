# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: desired_lrp_requests.proto

require 'google/protobuf'

require 'desired_lrp_pb'
require 'error_pb'
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "diego.bbs.models.DesiredLRPLifecycleResponse" do
    optional :error, :message, 1, "diego.bbs.models.Error"
  end
  add_message "diego.bbs.models.DesiredLRPsResponse" do
    optional :error, :message, 1, "diego.bbs.models.Error"
    repeated :desired_lrps, :message, 2, "diego.bbs.models.DesiredLRP"
  end
  add_message "diego.bbs.models.DesiredLRPsRequest" do
    optional :domain, :string, 1
    repeated :process_guids, :string, 2
  end
  add_message "diego.bbs.models.DesiredLRPResponse" do
    optional :error, :message, 1, "diego.bbs.models.Error"
    optional :desired_lrp, :message, 2, "diego.bbs.models.DesiredLRP"
  end
  add_message "diego.bbs.models.DesiredLRPSchedulingInfosResponse" do
    optional :error, :message, 1, "diego.bbs.models.Error"
    repeated :desired_lrp_scheduling_infos, :message, 2, "diego.bbs.models.DesiredLRPSchedulingInfo"
  end
  add_message "diego.bbs.models.DesiredLRPSchedulingInfoByProcessGuidResponse" do
    optional :error, :message, 1, "diego.bbs.models.Error"
    optional :desired_lrp_scheduling_info, :message, 2, "diego.bbs.models.DesiredLRPSchedulingInfo"
  end
  add_message "diego.bbs.models.DesiredLRPByProcessGuidRequest" do
    optional :process_guid, :string, 1
  end
  add_message "diego.bbs.models.DesireLRPRequest" do
    optional :desired_lrp, :message, 1, "diego.bbs.models.DesiredLRP"
  end
  add_message "diego.bbs.models.UpdateDesiredLRPRequest" do
    optional :process_guid, :string, 1
    optional :update, :message, 2, "diego.bbs.models.DesiredLRPUpdate"
  end
  add_message "diego.bbs.models.RemoveDesiredLRPRequest" do
    optional :process_guid, :string, 1
  end
end

module Diego
  module Bbs
    module Models
      DesiredLRPLifecycleResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesiredLRPLifecycleResponse").msgclass
      DesiredLRPsResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesiredLRPsResponse").msgclass
      DesiredLRPsRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesiredLRPsRequest").msgclass
      DesiredLRPResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesiredLRPResponse").msgclass
      DesiredLRPSchedulingInfosResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesiredLRPSchedulingInfosResponse").msgclass
      DesiredLRPSchedulingInfoByProcessGuidResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesiredLRPSchedulingInfoByProcessGuidResponse").msgclass
      DesiredLRPByProcessGuidRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesiredLRPByProcessGuidRequest").msgclass
      DesireLRPRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.DesireLRPRequest").msgclass
      UpdateDesiredLRPRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.UpdateDesiredLRPRequest").msgclass
      RemoveDesiredLRPRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.RemoveDesiredLRPRequest").msgclass
    end
  end
end
