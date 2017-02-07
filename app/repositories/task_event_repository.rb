module VCAP
  module CloudController
    module Repositories
      class TaskEventRepository
        def record_task_create(task, user_audit_info)
          record_event(task, user_audit_info, 'audit.app.task.create')
        end

        def record_task_cancel(task, user_audit_info)
          record_event(task, user_audit_info, 'audit.app.task.cancel')
        end

        private

        def record_event(task, user_audit_info, type)
          Event.create(
            type:              type,
            actor:             user_audit_info.user_guid,
            actor_type:        'user',
            actor_name:        user_audit_info.user_email,
            actor_username:    user_audit_info.user_name,
            actee:             task.app.guid,
            actee_type:        'app',
            actee_name:        task.app.name,
            timestamp:         Sequel::CURRENT_TIMESTAMP,
            metadata:          {
              task_guid: task.guid,
              request:   {
                name:                  task.name,
                memory_in_mb:          task.memory_in_mb,
                command:               'PRIVATE DATA HIDDEN'
              }
            },
            space_guid:        task.space.guid,
            organization_guid: task.space.organization.guid,
          )
        end
      end
    end
  end
end
