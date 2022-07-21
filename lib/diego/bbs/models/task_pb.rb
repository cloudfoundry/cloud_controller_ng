# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: task.proto

require 'google/protobuf'

require 'actions_pb'
require 'environment_variables_pb'
require 'security_group_pb'
require 'cached_dependency_pb'
require 'volume_mount_pb'
require 'network_pb'
require 'certificate_properties_pb'
require 'image_layer_pb'
require 'log_rate_limit_pb'
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "diego.bbs.models.TaskDefinition" do
    optional :root_fs, :string, 1
    repeated :environment_variables, :message, 2, "diego.bbs.models.EnvironmentVariable"
    optional :action, :message, 3, "diego.bbs.models.Action"
    optional :disk_mb, :int32, 4
    optional :memory_mb, :int32, 5
    optional :cpu_weight, :uint32, 6
    optional :privileged, :bool, 7
    optional :log_source, :string, 8
    optional :log_guid, :string, 9
    optional :metrics_guid, :string, 10
    optional :result_file, :string, 11
    optional :completion_callback_url, :string, 12
    optional :annotation, :string, 13
    repeated :egress_rules, :message, 14, "diego.bbs.models.SecurityGroupRule"
    repeated :cached_dependencies, :message, 15, "diego.bbs.models.CachedDependency"
    optional :legacy_download_user, :string, 16
    optional :trusted_system_certificates_path, :string, 17
    repeated :volume_mounts, :message, 18, "diego.bbs.models.VolumeMount"
    optional :network, :message, 19, "diego.bbs.models.Network"
    repeated :placement_tags, :string, 20
    optional :max_pids, :int32, 21
    optional :certificate_properties, :message, 22, "diego.bbs.models.CertificateProperties"
    optional :image_username, :string, 23
    optional :image_password, :string, 24
    repeated :image_layers, :message, 25, "diego.bbs.models.ImageLayer"
    optional :log_rate_limit, :message, 26, "diego.bbs.models.LogRateLimit"
  end
  add_message "diego.bbs.models.Task" do
    optional :task_definition, :message, 1, "diego.bbs.models.TaskDefinition"
    optional :task_guid, :string, 2
    optional :domain, :string, 3
    optional :created_at, :int64, 4
    optional :updated_at, :int64, 5
    optional :first_completed_at, :int64, 6
    optional :state, :enum, 7, "diego.bbs.models.Task.State"
    optional :cell_id, :string, 8
    optional :result, :string, 9
    optional :failed, :bool, 10
    optional :failure_reason, :string, 11
    optional :rejection_count, :int32, 12
    optional :rejection_reason, :string, 13
  end
  add_enum "diego.bbs.models.Task.State" do
    value :Invalid, 0
    value :Pending, 1
    value :Running, 2
    value :Completed, 3
    value :Resolving, 4
  end
end

module Diego
  module Bbs
    module Models
      TaskDefinition = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.TaskDefinition").msgclass
      Task = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.Task").msgclass
      Task::State = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.Task.State").enummodule
    end
  end
end
