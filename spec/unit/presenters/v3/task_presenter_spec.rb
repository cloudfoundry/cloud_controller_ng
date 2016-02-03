require 'spec_helper'
require 'presenters/v3/task_presenter'

module VCAP::CloudController
  describe TaskPresenter do
    describe '#present_json' do
      it 'presents the task as json' do
        task = TaskModel.make(
          environment_variables: { 'some' => 'stuff' },
          failure_reason: 'sup dawg',
          memory_in_mb: 2048,
          updated_at: Time.now,
        )

        json_result = TaskPresenter.new.present_json(task)
        result      = MultiJson.load(json_result)

        links = {
          'self'  => { 'href' => "/v3/tasks/#{task.guid}" },
          'app'   => { 'href' => "/v3/apps/#{task.app.guid}" },
          'droplet' => { 'href' => "/v3/droplets/#{task.droplet.guid}" },
        }

        expect(result['guid']).to eq(task.guid)
        expect(result['name']).to eq(task.name)
        expect(result['command']).to eq(task.command)
        expect(result['state']).to eq(task.state)
        expect(result['result']['failure_reason']).to eq 'sup dawg'
        expect(result['environment_variables']).to eq(task.environment_variables)
        expect(result['memory_in_mb']).to eq(task.memory_in_mb)
        expect(result['created_at']).to eq(task.created_at.iso8601)
        expect(result['updated_at']).to eq(task.updated_at.iso8601)
        expect(result['links']).to eq(links)
      end
    end

    describe '#present_json_list' do
      let(:pagination_presenter) { instance_double(PaginationPresenter, :pagination_presenter, present_pagination_hash: 'pagination_stuff') }
      let(:options) { { page: 1, per_page: 2 } }
      let(:app) { AppModel.make }
      let(:task_1) { TaskModel.make(app: app) }
      let(:task_2) { TaskModel.make(app: app) }
      let(:presenter) { TaskPresenter.new(pagination_presenter) }
      let(:tasks) { [task_1, task_2] }
      let(:total_results) { 2 }
      let(:paginated_result) { PaginatedResult.new(tasks, total_results, PaginationOptions.new(options)) }
      let(:message) { instance_double(TasksListMessage, to_param_hash: {}) }

      it 'presents the tasks as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result, "/v3/apps/#{app.guid}/tasks", message)
        result = MultiJson.load(json_result)
        guids = result['resources'].collect { |task_json| task_json['guid'] }

        expect(guids).to eq([task_1.guid, task_2.guid])
      end

      it 'includes pagination section' do
        json_result = presenter.present_json_list(paginated_result, "/v3/apps/#{app.guid}/tasks", message)
        result      = MultiJson.load(json_result)

        expect(result['pagination']).to eq('pagination_stuff')
      end
    end
  end
end
