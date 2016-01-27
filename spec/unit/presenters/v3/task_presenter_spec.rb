require 'spec_helper'
require 'presenters/v3/task_presenter'

module VCAP::CloudController
  describe TaskPresenter do
    describe '#present_json' do
      it 'presents the task as json' do
        task = TaskModel.make(
          environment_variables: { 'some' => 'stuff' },
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
        expect(result['result']['message']).to be_nil
        expect(result['environment_variables']).to eq(task.environment_variables)
        expect(result['links']).to eq(links)
      end
    end
  end
end
