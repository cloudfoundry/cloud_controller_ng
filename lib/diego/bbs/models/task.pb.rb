## Generated from task.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class TaskDefinition
        include Beefcake::Message
      end

      class Task
        include Beefcake::Message

        module State
          Invalid   = 0
          Pending   = 1
          Running   = 2
          Completed = 3
          Resolving = 4
        end
      end

      class TaskDefinition
        optional :root_fs, :string, 1
        repeated :environment_variables, EnvironmentVariable, 2
        optional :action, Action, 3
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
        repeated :egress_rules, SecurityGroupRule, 14
        repeated :cached_dependencies, CachedDependency, 15
        optional :legacy_download_user, :string, 16
        optional :trusted_system_certificates_path, :string, 17
        repeated :volume_mounts, VolumeMount, 18
        optional :network, Network, 19
        repeated :PlacementTags, :string, 20
      end

      class Task
        optional :task_definition, TaskDefinition, 1
        optional :task_guid, :string, 2
        optional :domain, :string, 3
        optional :created_at, :int64, 4
        optional :updated_at, :int64, 5
        optional :first_completed_at, :int64, 6
        optional :state, Task::State, 7
        optional :cell_id, :string, 8
        optional :result, :string, 9
        optional :failed, :bool, 10
        optional :failure_reason, :string, 11
      end
    end
  end
end
