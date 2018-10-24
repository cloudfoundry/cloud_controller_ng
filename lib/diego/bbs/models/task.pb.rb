# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'
require 'actions.pb'
require 'environment_variables.pb'
require 'security_group.pb'
require 'cached_dependency.pb'
require 'volume_mount.pb'
require 'network.pb'
require 'certificate_properties.pb'

module Diego
  module Bbs
    module Models

      ##
      # Message Classes
      #
      class TaskDefinition < ::Protobuf::Message; end
      class Task < ::Protobuf::Message
        class State < ::Protobuf::Enum
          define :Invalid, 0
          define :Pending, 1
          define :Running, 2
          define :Completed, 3
          define :Resolving, 4
        end

      end



      ##
      # Message Fields
      #
      class TaskDefinition
        optional :string, :root_fs, 1
        repeated ::Diego::Bbs::Models::EnvironmentVariable, :environment_variables, 2
        optional ::Diego::Bbs::Models::Action, :action, 3
        optional :int32, :disk_mb, 4
        optional :int32, :memory_mb, 5
        optional :uint32, :cpu_weight, 6
        optional :bool, :privileged, 7
        optional :string, :log_source, 8
        optional :string, :log_guid, 9
        optional :string, :metrics_guid, 10
        optional :string, :result_file, 11
        optional :string, :completion_callback_url, 12
        optional :string, :annotation, 13
        repeated ::Diego::Bbs::Models::SecurityGroupRule, :egress_rules, 14
        repeated ::Diego::Bbs::Models::CachedDependency, :cached_dependencies, 15
        optional :string, :legacy_download_user, 16
        optional :string, :trusted_system_certificates_path, 17
        repeated ::Diego::Bbs::Models::VolumeMount, :volume_mounts, 18
        optional ::Diego::Bbs::Models::Network, :network, 19
        repeated :string, :PlacementTags, 20
        optional :int32, :max_pids, 21
        optional ::Diego::Bbs::Models::CertificateProperties, :certificate_properties, 22
        optional :string, :image_username, 23
        optional :string, :image_password, 24
      end

      class Task
        optional ::Diego::Bbs::Models::TaskDefinition, :task_definition, 1
        optional :string, :task_guid, 2
        optional :string, :domain, 3
        optional :int64, :created_at, 4
        optional :int64, :updated_at, 5
        optional :int64, :first_completed_at, 6
        optional ::Diego::Bbs::Models::Task::State, :state, 7
        optional :string, :cell_id, 8
        optional :string, :result, 9
        optional :bool, :failed, 10
        optional :string, :failure_reason, 11
      end

    end

  end

end

