# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'
require 'task.pb'
require 'error.pb'

module Diego
  module Bbs
    module Models

      ##
      # Message Classes
      #
      class TaskLifecycleResponse < ::Protobuf::Message; end
      class DesireTaskRequest < ::Protobuf::Message; end
      class StartTaskRequest < ::Protobuf::Message; end
      class StartTaskResponse < ::Protobuf::Message; end
      class FailTaskRequest < ::Protobuf::Message; end
      class TaskGuidRequest < ::Protobuf::Message; end
      class CompleteTaskRequest < ::Protobuf::Message; end
      class TaskCallbackResponse < ::Protobuf::Message; end
      class ConvergeTasksRequest < ::Protobuf::Message; end
      class ConvergeTasksResponse < ::Protobuf::Message; end
      class TasksRequest < ::Protobuf::Message; end
      class TasksResponse < ::Protobuf::Message; end
      class TaskByGuidRequest < ::Protobuf::Message; end
      class TaskResponse < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class TaskLifecycleResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
      end

      class DesireTaskRequest
        optional ::Diego::Bbs::Models::TaskDefinition, :task_definition, 1
        optional :string, :task_guid, 2
        optional :string, :domain, 3
      end

      class StartTaskRequest
        optional :string, :task_guid, 1
        optional :string, :cell_id, 2
      end

      class StartTaskResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        optional :bool, :should_start, 2
      end

      class FailTaskRequest
        optional :string, :task_guid, 1
        optional :string, :failure_reason, 2
      end

      class TaskGuidRequest
        optional :string, :task_guid, 1
      end

      class CompleteTaskRequest
        optional :string, :task_guid, 1
        optional :string, :cell_id, 2
        optional :bool, :failed, 3
        optional :string, :failure_reason, 4
        optional :string, :result, 5
      end

      class TaskCallbackResponse
        optional :string, :task_guid, 1
        optional :bool, :failed, 2
        optional :string, :failure_reason, 3
        optional :string, :result, 4
        optional :string, :annotation, 5
        optional :int64, :created_at, 6
      end

      class ConvergeTasksRequest
        optional :int64, :kick_task_duration, 1
        optional :int64, :expire_pending_task_duration, 2
        optional :int64, :expire_completed_task_duration, 3
      end

      class ConvergeTasksResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
      end

      class TasksRequest
        optional :string, :domain, 1
        optional :string, :cell_id, 2
      end

      class TasksResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        repeated ::Diego::Bbs::Models::Task, :tasks, 2
      end

      class TaskByGuidRequest
        optional :string, :task_guid, 1
      end

      class TaskResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        optional ::Diego::Bbs::Models::Task, :task, 2
      end

    end

  end

end

