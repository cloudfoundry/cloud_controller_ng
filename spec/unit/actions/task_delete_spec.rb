require 'spec_helper'
require 'actions/task_delete'

module VCAP::CloudController
  RSpec.describe TaskDelete do
    describe '#delete_for_app' do
      subject(:task_delete) { described_class.new(user_audit_info) }

      let!(:app) { AppModel.make }
      let!(:task1) { TaskModel.make(app: app, state: TaskModel::SUCCEEDED_STATE) }
      let!(:task2) { TaskModel.make(app: app, state: TaskModel::FAILED_STATE) }
      let!(:task3) { TaskModel.make(app: app, state: TaskModel::PENDING_STATE) }
      let!(:task4) { TaskModel.make(app: app, state: TaskModel::RUNNING_STATE) }
      let!(:task5) { TaskModel.make(app: app, state: TaskModel::CANCELING_STATE) }
      let(:user_audit_info) { instance_double(VCAP::CloudController::UserAuditInfo).as_null_object }
      let(:bbs_task_client) { instance_double(VCAP::CloudController::Diego::BbsTaskClient, cancel_task: nil) }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:bbs_task_client).and_return(bbs_task_client)
      end

      it 'deletes the tasks' do
        expect do
          task_delete.delete_for_app(app.guid)
        end.to change(TaskModel, :count).by(-5)
        [task1, task2, task3, task4, task5].each { |t| expect(t).not_to exist }
      end

      it 'deletes associated labels' do
        label1 = TaskLabelModel.make(task: task1, key_name: 'test', value: 'bommel')
        label2 = TaskLabelModel.make(task: task2, key_name: 'test', value: 'bommel')

        expect do
          task_delete.delete_for_app(app.guid)
        end.to change(TaskLabelModel, :count).by(-2)
        [label1, label2].each { |l| expect(l).not_to exist }
      end

      it 'deletes associated annotations' do
        annotation1 = TaskAnnotationModel.make(task: task1, key_name: 'test', value: 'bommel')
        annotation2 = TaskAnnotationModel.make(task: task2, key_name: 'test', value: 'bommel')

        expect do
          task_delete.delete_for_app(app.guid)
        end.to change(TaskAnnotationModel, :count).by(-2)
        [annotation1, annotation2].each { |a| expect(a).not_to exist }
      end

      it 'sends a cancel request to bbs_task_client for RUNNING tasks' do
        task_delete.delete_for_app(app.guid)
        expect(bbs_task_client).to have_received(:cancel_task).once
        expect(bbs_task_client).to have_received(:cancel_task).with(task4.guid)
      end

      it 'creates an audit event for RUNNING tasks' do
        task_delete.delete_for_app(app.guid)

        events = Event.where(actee: app.guid).all
        expect(events.size).to eq(1)
        expect(events[0].type).to eq('audit.app.task.cancel')
        expect(events[0].metadata['task_guid']).to eq(task4.guid)
      end

      it 'creates a usage event for non-terminal tasks' do
        task_delete.delete_for_app(app.guid)

        events = AppUsageEvent.where(parent_app_guid: app.guid).all
        expect(events.size).to eq(3)
        task_guids = [task3.guid, task4.guid, task5.guid]
        events.each do |event|
          expect(event.state).to eq('TASK_STOPPED')
          expect(task_guids.delete(event.task_guid)).not_to be_nil
        end
        expect(task_guids).to be_empty
      end
    end
  end
end
