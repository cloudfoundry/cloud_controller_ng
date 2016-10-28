## Generated from task_requests.proto for models
require "beefcake"

module Diego
  module Bbs
    module Models

      class TaskLifecycleResponse
        include Beefcake::Message
      end

      class DesireTaskRequest
        include Beefcake::Message
      end

      class StartTaskRequest
        include Beefcake::Message
      end

      class StartTaskResponse
        include Beefcake::Message
      end

      class FailTaskRequest
        include Beefcake::Message
      end

      class TaskGuidRequest
        include Beefcake::Message
      end

      class CompleteTaskRequest
        include Beefcake::Message
      end

      class TaskCallbackResponse
        include Beefcake::Message
      end

      class ConvergeTasksRequest
        include Beefcake::Message
      end

      class ConvergeTasksResponse
        include Beefcake::Message
      end

      class TasksRequest
        include Beefcake::Message
      end

      class TasksResponse
        include Beefcake::Message
      end

      class TaskByGuidRequest
        include Beefcake::Message
      end

      class TaskResponse
        include Beefcake::Message
      end

      class TaskLifecycleResponse
        optional :error, Error, 1
      end

      class DesireTaskRequest
        optional :task_definition, TaskDefinition, 1
        optional :task_guid, :string, 2
        optional :domain, :string, 3
      end

      class StartTaskRequest
        optional :task_guid, :string, 1
        optional :cell_id, :string, 2
      end

      class StartTaskResponse
        optional :error, Error, 1
        optional :should_start, :bool, 2
      end

      class FailTaskRequest
        optional :task_guid, :string, 1
        optional :failure_reason, :string, 2
      end

      class TaskGuidRequest
        optional :task_guid, :string, 1
      end

      class CompleteTaskRequest
        optional :task_guid, :string, 1
        optional :cell_id, :string, 2
        optional :failed, :bool, 3
        optional :failure_reason, :string, 4
        optional :result, :string, 5
      end

      class TaskCallbackResponse
        optional :task_guid, :string, 1
        optional :failed, :bool, 2
        optional :failure_reason, :string, 3
        optional :result, :string, 4
        optional :annotation, :string, 5
        optional :created_at, :int64, 6
      end

      class ConvergeTasksRequest
        optional :kick_task_duration, :int64, 1
        optional :expire_pending_task_duration, :int64, 2
        optional :expire_completed_task_duration, :int64, 3
      end

      class ConvergeTasksResponse
        optional :error, Error, 1
      end

      class TasksRequest
        optional :domain, :string, 1
        optional :cell_id, :string, 2
      end

      class TasksResponse
        optional :error, Error, 1
        repeated :tasks, Task, 2
      end

      class TaskByGuidRequest
        optional :task_guid, :string, 1
      end

      class TaskResponse
        optional :error, Error, 1
        optional :task, Task, 2
      end
    end
  end
end
