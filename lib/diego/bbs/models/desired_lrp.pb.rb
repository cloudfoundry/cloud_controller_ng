# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf'


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
require 'image_layer.pb'

module Diego
  module Bbs
    module Models
      ::Protobuf::Optionable.inject(self) { ::Google::Protobuf::FileOptions }

      ##
      # Message Classes
      #
      class DesiredLRPSchedulingInfo < ::Protobuf::Message; end
      class DesiredLRPRunInfo < ::Protobuf::Message; end
      class ProtoRoutes < ::Protobuf::Message
      end

      class DesiredLRPUpdate < ::Protobuf::Message; end
      class DesiredLRPKey < ::Protobuf::Message; end
      class DesiredLRPResource < ::Protobuf::Message; end
      class DesiredLRP < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class DesiredLRPSchedulingInfo
        optional ::Diego::Bbs::Models::DesiredLRPKey, :desired_lrp_key, 1, :".gogoproto.nullable" => false, :".gogoproto.embed" => true, :".gogoproto.jsontag" => ""
        optional :string, :annotation, 2
        optional :int32, :instances, 3
        optional ::Diego::Bbs::Models::DesiredLRPResource, :desired_lrp_resource, 4, :".gogoproto.nullable" => false, :".gogoproto.embed" => true, :".gogoproto.jsontag" => ""
        optional ::Diego::Bbs::Models::ProtoRoutes, :routes, 5, :".gogoproto.nullable" => false, :".gogoproto.customtype" => "Routes"
        optional ::Diego::Bbs::Models::ModificationTag, :modification_tag, 6, :".gogoproto.nullable" => false, :".gogoproto.embed" => true, :".gogoproto.jsontag" => ""
        optional ::Diego::Bbs::Models::VolumePlacement, :volume_placement, 7, :".gogoproto.jsontag" => "volume_placement,omitempty"
        repeated :string, :PlacementTags, 8, :".gogoproto.jsontag" => "placement_tags,omitempty"
      end

      class DesiredLRPRunInfo
        optional ::Diego::Bbs::Models::DesiredLRPKey, :desired_lrp_key, 1, :".gogoproto.nullable" => false, :".gogoproto.embed" => true, :".gogoproto.jsontag" => ""
        repeated ::Diego::Bbs::Models::EnvironmentVariable, :environment_variables, 2, :".gogoproto.nullable" => false, :".gogoproto.jsontag" => "env"
        optional ::Diego::Bbs::Models::Action, :setup, 3
        optional ::Diego::Bbs::Models::Action, :action, 4
        optional ::Diego::Bbs::Models::Action, :monitor, 5
        optional :uint32, :deprecated_start_timeout_s, 6, :deprecated => true, :".gogoproto.jsontag" => "start_timeout,omitempty"
        optional :bool, :privileged, 7
        optional :uint32, :cpu_weight, 8
        repeated :uint32, :ports, 9
        repeated ::Diego::Bbs::Models::SecurityGroupRule, :egress_rules, 10, :".gogoproto.nullable" => false
        optional :string, :log_source, 11
        optional :string, :metrics_guid, 12
        optional :int64, :created_at, 13
        repeated ::Diego::Bbs::Models::CachedDependency, :cached_dependencies, 14, :".gogoproto.jsontag" => "cached_dependencies,omitempty"
        optional :string, :legacy_download_user, 15, :deprecated => true, :".gogoproto.jsontag" => "legacy_download_user,omitempty"
        optional :string, :trusted_system_certificates_path, 16, :".gogoproto.jsontag" => "trusted_system_certificates_path,omitempty"
        repeated ::Diego::Bbs::Models::VolumeMount, :volume_mounts, 17, :".gogoproto.jsontag" => "volume_mounts,omitempty"
        optional ::Diego::Bbs::Models::Network, :network, 18, :".gogoproto.jsontag" => "network,omitempty"
        optional :int64, :start_timeout_ms, 19
        optional ::Diego::Bbs::Models::CertificateProperties, :certificate_properties, 20, :".gogoproto.nullable" => true, :".gogoproto.jsontag" => "certificate_properties,omitempty"
        optional :string, :image_username, 21, :".gogoproto.nullable" => false, :".gogoproto.jsontag" => "image_username,omitempty"
        optional :string, :image_password, 22, :".gogoproto.nullable" => false, :".gogoproto.jsontag" => "image_password,omitempty"
        optional ::Diego::Bbs::Models::CheckDefinition, :check_definition, 23, :".gogoproto.jsontag" => "check_definition,omitempty"
        repeated ::Diego::Bbs::Models::ImageLayer, :image_layers, 24
      end

      class ProtoRoutes
        map :string, :bytes, :routes, 1
      end

      class DesiredLRPUpdate
        optional :int32, :instances, 1, :".gogoproto.nullable" => true
        optional ::Diego::Bbs::Models::ProtoRoutes, :routes, 2, :".gogoproto.nullable" => true, :".gogoproto.customtype" => "Routes"
        optional :string, :annotation, 3, :".gogoproto.nullable" => true
      end

      class DesiredLRPKey
        optional :string, :process_guid, 1
        optional :string, :domain, 2
        optional :string, :log_guid, 3
      end

      class DesiredLRPResource
        optional :int32, :memory_mb, 1
        optional :int32, :disk_mb, 2
        optional :string, :root_fs, 3, :".gogoproto.jsontag" => "rootfs"
        optional :int32, :max_pids, 4
      end

      class DesiredLRP
        optional :string, :process_guid, 1
        optional :string, :domain, 2
        optional :string, :root_fs, 3, :".gogoproto.jsontag" => "rootfs"
        optional :int32, :instances, 4
        repeated ::Diego::Bbs::Models::EnvironmentVariable, :environment_variables, 5, :".gogoproto.jsontag" => "env"
        optional ::Diego::Bbs::Models::Action, :setup, 6
        optional ::Diego::Bbs::Models::Action, :action, 7
        optional :int64, :start_timeout_ms, 27
        optional :uint32, :deprecated_start_timeout_s, 8, :deprecated => true, :".gogoproto.jsontag" => "deprecated_timeout_ns,omitempty"
        optional ::Diego::Bbs::Models::Action, :monitor, 9
        optional :int32, :disk_mb, 10
        optional :int32, :memory_mb, 11
        optional :uint32, :cpu_weight, 12
        optional :bool, :privileged, 13
        repeated :uint32, :ports, 14
        optional ::Diego::Bbs::Models::ProtoRoutes, :routes, 15, :".gogoproto.nullable" => true, :".gogoproto.customtype" => "Routes"
        optional :string, :log_source, 16
        optional :string, :log_guid, 17
        optional :string, :metrics_guid, 18
        optional :string, :annotation, 19
        repeated ::Diego::Bbs::Models::SecurityGroupRule, :egress_rules, 20
        optional ::Diego::Bbs::Models::ModificationTag, :modification_tag, 21
        repeated ::Diego::Bbs::Models::CachedDependency, :cached_dependencies, 22, :".gogoproto.jsontag" => "cached_dependencies,omitempty"
        optional :string, :legacy_download_user, 23, :deprecated => true, :".gogoproto.jsontag" => "legacy_download_user,omitempty"
        optional :string, :trusted_system_certificates_path, 24, :".gogoproto.jsontag" => "trusted_system_certificates_path,omitempty"
        repeated ::Diego::Bbs::Models::VolumeMount, :volume_mounts, 25, :".gogoproto.jsontag" => "volume_mounts,omitempty"
        optional ::Diego::Bbs::Models::Network, :network, 26, :".gogoproto.jsontag" => "network,omitempty"
        repeated :string, :PlacementTags, 28, :".gogoproto.jsontag" => "placement_tags,omitempty"
        optional :int32, :max_pids, 29
        optional ::Diego::Bbs::Models::CertificateProperties, :certificate_properties, 30, :".gogoproto.nullable" => true, :".gogoproto.jsontag" => "certificate_properties,omitempty"
        optional :string, :image_username, 31, :".gogoproto.nullable" => false, :".gogoproto.jsontag" => "image_username,omitempty"
        optional :string, :image_password, 32, :".gogoproto.nullable" => false, :".gogoproto.jsontag" => "image_password,omitempty"
        optional ::Diego::Bbs::Models::CheckDefinition, :check_definition, 33, :".gogoproto.jsontag" => "check_definition,omitempty"
        repeated ::Diego::Bbs::Models::ImageLayer, :image_layers, 34
      end

    end

  end

end

