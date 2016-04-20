module VCAP
  module CloudController
    module Repositories
      class TaskEventRepository
        def record_task_create(task, user_guid, user_email)
          record_event(task, user_guid, user_email, 'audit.app.task.create')
        end

        def record_task_cancel(task, user_guid, user_email)
          record_event(task, user_guid, user_email, 'audit.app.task.cancel')
        end

        private

        def record_event(task, user_guid, user_email, type)
          Event.create(
            type:              type,
            actor:             user_guid,
            actor_type:        'user',
            actor_name:        user_email,
            actee:             task.app.guid,
            actee_type:        'v3-app',
            actee_name:        task.app.name,
            timestamp:         Sequel::CURRENT_TIMESTAMP,
            metadata:          {
              task_guid: task.guid,
              request:   {
                name:                  task.name,
                memory_in_mb:          task.memory_in_mb,
                environment_variables: 'PRIVATE DATA HIDDEN',
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
