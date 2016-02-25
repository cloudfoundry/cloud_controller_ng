require 'spec_helper'

module VCAP
  module CloudController
    module Repositories
      module Runtime
        describe TaskEventRepository do
          let(:task) { TaskModel.make }
          let(:user_guid) { 'user-guid' }
          let(:user_email) { 'user-email' }

          subject(:task_event_repository) { TaskEventRepository.new }

          describe '#record_task_create' do
            it 'records task create event correctly' do
              event = task_event_repository.record_task_create(task, user_guid, user_email)

              expect(event.type).to eq('audit.app.task.create')
              expect(event.actor).to eq(user_guid)
              expect(event.actor_type).to eq('user')
              expect(event.actor_name).to eq(user_email)
              expect(event.actee).to eq(task.app.guid)
              expect(event.actee_type).to eq('v3-app')
              expect(event.actee_name).to eq(task.app.name)
              expect(event.metadata[:task_guid]).to eq(task.guid)
              expect(event.metadata[:request]).to eq(
                {
                  name: task.name,
                  memory_in_mb: task.memory_in_mb,
                  environment_variables: 'PRIVATE DATA HIDDEN',
                  command: 'PRIVATE DATA HIDDEN'
                }
              )
              expect(event.space_guid).to eq(task.space.guid)
              expect(event.organization_guid).to eq(task.space.organization.guid)
            end
          end

          describe '#record_task_cancel' do
            it 'records task cancel event correctly' do
              event = task_event_repository.record_task_cancel(task, user_guid, user_email)

              expect(event.type).to eq('audit.app.task.cancel')
              expect(event.actor).to eq(user_guid)
              expect(event.actor_type).to eq('user')
              expect(event.actor_name).to eq(user_email)
              expect(event.actee).to eq(task.app.guid)
              expect(event.actee_type).to eq('v3-app')
              expect(event.actee_name).to eq(task.app.name)
              expect(event.metadata[:task_guid]).to eq(task.guid)
              expect(event.metadata[:request]).to eq(
                {
                  name: task.name,
                  memory_in_mb: task.memory_in_mb,
                  environment_variables: 'PRIVATE DATA HIDDEN',
                  command: 'PRIVATE DATA HIDDEN'
                }
              )
              expect(event.space_guid).to eq(task.space.guid)
              expect(event.organization_guid).to eq(task.space.organization.guid)
            end
          end
        end
      end
    end
  end
end
