## Generated from desired_lrp.proto for models
require "beefcake"

require_relative 'actions.pb'
require_relative 'cached_dependency.pb'
require_relative 'environment_variables.pb'
require_relative 'modification_tag.pb'
require_relative 'network.pb'
require_relative 'security_group.pb'
require_relative 'volume_mount.pb'


module Diego
  module Bbs
    module Models

      class DesiredLRPSchedulingInfo
        include Beefcake::Message
      end

      class DesiredLRPRunInfo
        include Beefcake::Message
      end

      class ProtoRoutes
        include Beefcake::Message

        class RoutesEntry
          include Beefcake::Message
        end
      end

      class DesiredLRPUpdate
        include Beefcake::Message
      end

      class DesiredLRPKey
        include Beefcake::Message
      end

      class DesiredLRPResource
        include Beefcake::Message
      end

      class DesiredLRP
        include Beefcake::Message
      end

      class DesiredLRPSchedulingInfo
        optional :desired_lrp_key, DesiredLRPKey, 1
        optional :annotation, :string, 2
        optional :instances, :int32, 3
        optional :desired_lrp_resource, DesiredLRPResource, 4
        optional :routes, :bytes, 5
        optional :modification_tag, ModificationTag, 6
        optional :volume_placement, VolumePlacement, 7
        repeated :PlacementTags, :string, 8
      end

      class DesiredLRPRunInfo
        optional :desired_lrp_key, DesiredLRPKey, 1
        repeated :environment_variables, EnvironmentVariable, 2
        optional :setup, Action, 3
        optional :action, Action, 4
        optional :monitor, Action, 5
        optional :deprecated_start_timeout_s, :uint32, 6
        optional :privileged, :bool, 7
        optional :cpu_weight, :uint32, 8
        repeated :ports, :uint32, 9
        repeated :egress_rules, SecurityGroupRule, 10
        optional :log_source, :string, 11
        optional :metrics_guid, :string, 12
        optional :created_at, :int64, 13
        repeated :cached_dependencies, CachedDependency, 14
        optional :legacy_download_user, :string, 15
        optional :trusted_system_certificates_path, :string, 16
        repeated :volume_mounts, VolumeMount, 17
        optional :network, Network, 18
        optional :start_timeout_ms, :int64, 19
      end

      class ProtoRoutes

        class RoutesEntry
          optional :key, :string, 1
          optional :value, :bytes, 2
        end
        repeated :routes, ProtoRoutes::RoutesEntry, 1
      end

      class DesiredLRPUpdate
        optional :instances, :int32, 1
        optional :routes, :bytes, 2
        optional :annotation, :string, 3
      end

      class DesiredLRPKey
        optional :process_guid, :string, 1
        optional :domain, :string, 2
        optional :log_guid, :string, 3
      end

      class DesiredLRPResource
        optional :memory_mb, :int32, 1
        optional :disk_mb, :int32, 2
        optional :root_fs, :string, 3
      end

      class DesiredLRP
        optional :process_guid, :string, 1
        optional :domain, :string, 2
        optional :root_fs, :string, 3
        optional :instances, :int32, 4
        repeated :environment_variables, EnvironmentVariable, 5
        optional :setup, Action, 6
        optional :action, Action, 7
        optional :start_timeout_ms, :int64, 27
        optional :deprecated_start_timeout_s, :uint32, 8
        optional :monitor, Action, 9
        optional :disk_mb, :int32, 10
        optional :memory_mb, :int32, 11
        optional :cpu_weight, :uint32, 12
        optional :privileged, :bool, 13
        repeated :ports, :uint32, 14
        optional :routes, :bytes, 15
        optional :log_source, :string, 16
        optional :log_guid, :string, 17
        optional :metrics_guid, :string, 18
        optional :annotation, :string, 19
        repeated :egress_rules, SecurityGroupRule, 20
        optional :modification_tag, ModificationTag, 21
        repeated :cached_dependencies, CachedDependency, 22
        optional :legacy_download_user, :string, 23
        optional :trusted_system_certificates_path, :string, 24
        repeated :volume_mounts, VolumeMount, 25
        optional :network, Network, 26
        repeated :PlacementTags, :string, 28
      end
    end
  end
end
