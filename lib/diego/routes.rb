module Diego
  module Routes
    PING         = '/v1/ping'.freeze
    DESIRE_TASK  = '/v1/tasks/desire.r2'.freeze
    CANCEL_TASK  = '/v1/tasks/cancel'.freeze
    LIST_TASKS   = '/v1/tasks/list.r2'.freeze
    TASK_BY_GUID = '/v1/tasks/get_by_task_guid.r2'.freeze
    DESIRE_LRP   = '/v1/desired_lrp/desire.r2'.freeze
  end
end
