## Generated from actions.proto for models
require "beefcake"

require_relative 'environment_variables.pb'


module Diego
  module Bbs
    module Models

      class Action
        include Beefcake::Message
      end

      class DownloadAction
        include Beefcake::Message
      end

      class UploadAction
        include Beefcake::Message
      end

      class RunAction
        include Beefcake::Message
      end

      class TimeoutAction
        include Beefcake::Message
      end

      class EmitProgressAction
        include Beefcake::Message
      end

      class TryAction
        include Beefcake::Message
      end

      class ParallelAction
        include Beefcake::Message
      end

      class SerialAction
        include Beefcake::Message
      end

      class CodependentAction
        include Beefcake::Message
      end

      class ResourceLimits
        include Beefcake::Message
      end

      class Action
        optional :download_action, DownloadAction, 1
        optional :upload_action, UploadAction, 2
        optional :run_action, RunAction, 3
        optional :timeout_action, TimeoutAction, 4
        optional :emit_progress_action, EmitProgressAction, 5
        optional :try_action, TryAction, 6
        optional :parallel_action, ParallelAction, 7
        optional :serial_action, SerialAction, 8
        optional :codependent_action, CodependentAction, 9
      end

      class DownloadAction
        optional :artifact, :string, 1
        optional :from, :string, 2
        optional :to, :string, 3
        optional :cache_key, :string, 4
        optional :log_source, :string, 5
        optional :user, :string, 6
        optional :checksum_algorithm, :string, 7
        optional :checksum_value, :string, 8
      end

      class UploadAction
        optional :artifact, :string, 1
        optional :from, :string, 2
        optional :to, :string, 3
        optional :log_source, :string, 4
        optional :user, :string, 5
      end

      class RunAction
        optional :path, :string, 1
        repeated :args, :string, 2
        optional :dir, :string, 3
        repeated :env, EnvironmentVariable, 4
        optional :resource_limits, ResourceLimits, 5
        optional :user, :string, 6
        optional :log_source, :string, 7
        optional :suppress_log_output, :bool, 8
      end

      class TimeoutAction
        optional :action, Action, 1
        optional :deprecated_timeout_ns, :int64, 2
        optional :log_source, :string, 3
        optional :timeout_ms, :int64, 4
      end

      class EmitProgressAction
        optional :action, Action, 1
        optional :start_message, :string, 2
        optional :success_message, :string, 3
        optional :failure_message_prefix, :string, 4
        optional :log_source, :string, 5
      end

      class TryAction
        optional :action, Action, 1
        optional :log_source, :string, 2
      end

      class ParallelAction
        repeated :actions, Action, 1
        optional :log_source, :string, 2
      end

      class SerialAction
        repeated :actions, Action, 1
        optional :log_source, :string, 2
      end

      class CodependentAction
        repeated :actions, Action, 1
        optional :log_source, :string, 2
      end

      class ResourceLimits
        optional :nofile, :uint64, 1
        optional :nproc, :uint64, 2
      end
    end
  end
end
