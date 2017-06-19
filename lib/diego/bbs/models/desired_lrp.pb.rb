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
require 'cached_dependency.pb'
require 'certificate_properties.pb'
require 'environment_variables.pb'
require 'modification_tag.pb'
require 'network.pb'
require 'security_group.pb'
require 'volume_mount.pb'
require 'check_definition.pb'

module Diego
  module Bbs
    module Models

      ##
      # Message Classes
      #
      class DesiredLRPSchedulingInfo < ::Protobuf::Message; end
      class DesiredLRPRunInfo < ::Protobuf::Message; end
      class ProtoRoutes < ::Protobuf::Message
        class RoutesEntry < ::Protobuf::Message; end

      end

      class DesiredLRPUpdate < ::Protobuf::Message; end
      class DesiredLRPKey < ::Protobuf::Message; end
      class DesiredLRPResource < ::Protobuf::Message; end
      class DesiredLRP < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class DesiredLRPSchedulingInfo
        optional ::Diego::Bbs::Models::DesiredLRPKey, :desired_lrp_key, 1
        optional :string, :annotation, 2
        optional :int32, :instances, 3
        optional ::Diego::Bbs::Models::DesiredLRPResource, :desired_lrp_resource, 4
        optional ::Diego::Bbs::Models::ProtoRoutes, :routes, 5
        optional ::Diego::Bbs::Models::ModificationTag, :modification_tag, 6
        optional ::Diego::Bbs::Models::VolumePlacement, :volume_placement, 7
        repeated :string, :PlacementTags, 8
      end

      class DesiredLRPRunInfo
        optional ::Diego::Bbs::Models::DesiredLRPKey, :desired_lrp_key, 1
        repeated ::Diego::Bbs::Models::EnvironmentVariable, :environment_variables, 2
        optional ::Diego::Bbs::Models::Action, :setup, 3
        optional ::Diego::Bbs::Models::Action, :action, 4
        optional ::Diego::Bbs::Models::Action, :monitor, 5
        optional :uint32, :deprecated_start_timeout_s, 6, :deprecated => true
        optional :bool, :privileged, 7
        optional :uint32, :cpu_weight, 8
        repeated :uint32, :ports, 9
        repeated ::Diego::Bbs::Models::SecurityGroupRule, :egress_rules, 10
        optional :string, :log_source, 11
        optional :string, :metrics_guid, 12
        optional :int64, :created_at, 13
        repeated ::Diego::Bbs::Models::CachedDependency, :cached_dependencies, 14
        optional :string, :legacy_download_user, 15
        optional :string, :trusted_system_certificates_path, 16
        repeated ::Diego::Bbs::Models::VolumeMount, :volume_mounts, 17
        optional ::Diego::Bbs::Models::Network, :network, 18
        optional :int64, :start_timeout_ms, 19
        optional ::Diego::Bbs::Models::CertificateProperties, :certificate_properties, 20
        optional :string, :image_username, 21
        optional :string, :image_password, 22
        optional ::Diego::Bbs::Models::CheckDefinition, :check_definition, 23
      end

      class ProtoRoutes
        class RoutesEntry
          optional :string, :key, 1
          optional :bytes, :value, 2
        end

        repeated ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry, :routes, 1
      end

      class DesiredLRPUpdate
        optional :int32, :instances, 1
        optional ::Diego::Bbs::Models::ProtoRoutes, :routes, 2
        optional :string, :annotation, 3
      end

      class DesiredLRPKey
        optional :string, :process_guid, 1
        optional :string, :domain, 2
        optional :string, :log_guid, 3
      end

      class DesiredLRPResource
        optional :int32, :memory_mb, 1
        optional :int32, :disk_mb, 2
        optional :string, :root_fs, 3
        optional :int32, :max_pids, 4
      end

      class DesiredLRP
        optional :string, :process_guid, 1
        optional :string, :domain, 2
        optional :string, :root_fs, 3
        optional :int32, :instances, 4
        repeated ::Diego::Bbs::Models::EnvironmentVariable, :environment_variables, 5
        optional ::Diego::Bbs::Models::Action, :setup, 6
        optional ::Diego::Bbs::Models::Action, :action, 7
        optional :int64, :start_timeout_ms, 27
        optional :uint32, :deprecated_start_timeout_s, 8, :deprecated => true
        optional ::Diego::Bbs::Models::Action, :monitor, 9
        optional :int32, :disk_mb, 10
        optional :int32, :memory_mb, 11
        optional :uint32, :cpu_weight, 12
        optional :bool, :privileged, 13
        repeated :uint32, :ports, 14
        optional ::Diego::Bbs::Models::ProtoRoutes, :routes, 15
        optional :string, :log_source, 16
        optional :string, :log_guid, 17
        optional :string, :metrics_guid, 18
        optional :string, :annotation, 19
        repeated ::Diego::Bbs::Models::SecurityGroupRule, :egress_rules, 20
        optional ::Diego::Bbs::Models::ModificationTag, :modification_tag, 21
        repeated ::Diego::Bbs::Models::CachedDependency, :cached_dependencies, 22
        optional :string, :legacy_download_user, 23
        optional :string, :trusted_system_certificates_path, 24
        repeated ::Diego::Bbs::Models::VolumeMount, :volume_mounts, 25
        optional ::Diego::Bbs::Models::Network, :network, 26
        repeated :string, :PlacementTags, 28
        optional :int32, :max_pids, 29
        optional ::Diego::Bbs::Models::CertificateProperties, :certificate_properties, 30
        optional :string, :image_username, 31
        optional :string, :image_password, 32
        optional ::Diego::Bbs::Models::CheckDefinition, :check_definition, 33
      end

    end

  end

end

