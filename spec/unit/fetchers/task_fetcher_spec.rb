require 'spec_helper'

module VCAP::CloudController
  RSpec.describe TaskFetcher do
    subject(:fetcher) { TaskFetcher.new }
    let(:app) { create(:app_model, space: space) }
    let(:space) { create(:space) }
    let(:task) { create(:task_model, app: app) }

    describe '#fetch_for_app' do
      it 'fetches the associated task, app, space' do
        returned_task, returned_app, returned_space = fetcher.fetch_for_app(task_guid: task.guid, app_guid: app.guid)
        expect(returned_task).to eq(task)
        expect(returned_app).to eq(app)
        expect(returned_space).to eq(space)
      end

      context 'when app is not found' do
        it 'returns nil' do
          returned_task, returned_app, returned_space = fetcher.fetch_for_app(task_guid: task.guid, app_guid: 'not-found')
          expect(returned_task).to be_nil
          expect(returned_app).to be_nil
          expect(returned_space).to be_nil
        end
      end
    end

    describe '#fetch' do
      it 'fetches the associated task and space' do
        returned_task, returned_space = fetcher.fetch(task_guid: task.guid)
        expect(returned_task).to eq(task)
        expect(returned_space).to eq(space)
      end

      context 'when task is not found' do
        it 'returns nil' do
          returned_task, returned_space = fetcher.fetch(task_guid: 'not-found')
          expect(returned_task).to be_nil
          expect(returned_space).to be_nil
        end
      end
    end
  end
end
