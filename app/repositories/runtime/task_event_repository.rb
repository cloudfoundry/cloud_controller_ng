module VCAP
  module CloudController
    module Repositories
      module Runtime
        class TaskEventRepository
          def record_task_create(task, user_guid, user_email)
            Event.create(
              type: 'audit.app.task.create',
              actor: user_guid,
              actor_type: 'user',
              actor_name: user_email,
              actee: task.app.guid,
              actee_type: 'v3-app',
              actee_name: task.app.name,
              timestamp: Sequel::CURRENT_TIMESTAMP,
              metadata: {
                task_guid: task.guid,
                request: {
                  name: task.name,
                  memory_in_mb: task.memory_in_mb,
                  environment_variables: 'PRIVATE DATA HIDDEN',
                  command: 'PRIVATE DATA HIDDEN'
                }
              },
              space_guid: task.space.guid,
              organization_guid: task.space.organization.guid,
            )
          end
        end
      end
    end
  end
end
