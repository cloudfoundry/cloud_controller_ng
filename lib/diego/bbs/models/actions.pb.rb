# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'
require 'environment_variables.pb'

module Diego
  module Bbs
    module Models
      ::Protobuf::Optionable.inject(self) { ::Google::Protobuf::FileOptions }

      ##
      # Message Classes
      #
      class Action < ::Protobuf::Message; end
      class DownloadAction < ::Protobuf::Message; end
      class UploadAction < ::Protobuf::Message; end
      class RunAction < ::Protobuf::Message; end
      class TimeoutAction < ::Protobuf::Message; end
      class EmitProgressAction < ::Protobuf::Message; end
      class TryAction < ::Protobuf::Message; end
      class ParallelAction < ::Protobuf::Message; end
      class SerialAction < ::Protobuf::Message; end
      class CodependentAction < ::Protobuf::Message; end
      class ResourceLimits < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class Action
        optional ::Diego::Bbs::Models::DownloadAction, :download_action, 1, :".gogoproto.jsontag" => "download,omitempty"
        optional ::Diego::Bbs::Models::UploadAction, :upload_action, 2, :".gogoproto.jsontag" => "upload,omitempty"
        optional ::Diego::Bbs::Models::RunAction, :run_action, 3, :".gogoproto.jsontag" => "run,omitempty"
        optional ::Diego::Bbs::Models::TimeoutAction, :timeout_action, 4, :".gogoproto.jsontag" => "timeout,omitempty"
        optional ::Diego::Bbs::Models::EmitProgressAction, :emit_progress_action, 5, :".gogoproto.jsontag" => "emit_progress,omitempty"
        optional ::Diego::Bbs::Models::TryAction, :try_action, 6, :".gogoproto.jsontag" => "try,omitempty"
        optional ::Diego::Bbs::Models::ParallelAction, :parallel_action, 7, :".gogoproto.jsontag" => "parallel,omitempty"
        optional ::Diego::Bbs::Models::SerialAction, :serial_action, 8, :".gogoproto.jsontag" => "serial,omitempty"
        optional ::Diego::Bbs::Models::CodependentAction, :codependent_action, 9, :".gogoproto.jsontag" => "codependent,omitempty"
      end

      class DownloadAction
        optional :string, :artifact, 1, :".gogoproto.jsontag" => "artifact,omitempty"
        optional :string, :from, 2
        optional :string, :to, 3
        optional :string, :cache_key, 4
        optional :string, :log_source, 5, :".gogoproto.jsontag" => "log_source,omitempty"
        optional :string, :user, 6
        optional :string, :checksum_algorithm, 7, :".gogoproto.jsontag" => "checksum_algorithm,omitempty"
        optional :string, :checksum_value, 8, :".gogoproto.jsontag" => "checksum_value,omitempty"
      end

      class UploadAction
        optional :string, :artifact, 1, :".gogoproto.jsontag" => "artifact,omitempty"
        optional :string, :from, 2
        optional :string, :to, 3
        optional :string, :log_source, 4, :".gogoproto.jsontag" => "log_source,omitempty"
        optional :string, :user, 5
      end

      class RunAction
        optional :string, :path, 1
        repeated :string, :args, 2
        optional :string, :dir, 3, :".gogoproto.jsontag" => "dir,omitempty"
        repeated ::Diego::Bbs::Models::EnvironmentVariable, :env, 4
        optional ::Diego::Bbs::Models::ResourceLimits, :resource_limits, 5
        optional :string, :user, 6
        optional :string, :log_source, 7, :".gogoproto.jsontag" => "log_source,omitempty"
        optional :bool, :suppress_log_output, 8
      end

      class TimeoutAction
        optional ::Diego::Bbs::Models::Action, :action, 1
        optional :int64, :deprecated_timeout_ns, 2, :deprecated => true, :".gogoproto.jsontag" => "timeout,omitempty"
        optional :string, :log_source, 3, :".gogoproto.jsontag" => "log_source,omitempty"
        optional :int64, :timeout_ms, 4
      end

      class EmitProgressAction
        optional ::Diego::Bbs::Models::Action, :action, 1
        optional :string, :start_message, 2
        optional :string, :success_message, 3
        optional :string, :failure_message_prefix, 4
        optional :string, :log_source, 5, :".gogoproto.jsontag" => "log_source,omitempty"
      end

      class TryAction
        optional ::Diego::Bbs::Models::Action, :action, 1
        optional :string, :log_source, 2, :".gogoproto.jsontag" => "log_source,omitempty"
      end

      class ParallelAction
        repeated ::Diego::Bbs::Models::Action, :actions, 1
        optional :string, :log_source, 2, :".gogoproto.jsontag" => "log_source,omitempty"
      end

      class SerialAction
        repeated ::Diego::Bbs::Models::Action, :actions, 1
        optional :string, :log_source, 2, :".gogoproto.jsontag" => "log_source,omitempty"
      end

      class CodependentAction
        repeated ::Diego::Bbs::Models::Action, :actions, 1
        optional :string, :log_source, 2, :".gogoproto.jsontag" => "log_source,omitempty"
      end

      class ResourceLimits
        optional :uint64, :nofile, 1, :".gogoproto.nullable" => true, :".gogoproto.jsontag" => "nofile,omitempty"
        optional :uint64, :nproc, 2, :deprecated => true, :".gogoproto.nullable" => true, :".gogoproto.jsontag" => "nproc,omitempty"
      end

    end

  end

end

