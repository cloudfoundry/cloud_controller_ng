require 'spec_helper'

module VCAP::CloudController
  describe TaskListFetcher do
    let(:space1) { Space.make }
    let(:app_in_space1) { AppModel.make(space_guid: space1.guid) }
    let(:app2_in_space1) { AppModel.make(space_guid: space1.guid) }

    let!(:task_in_space1) { TaskModel.make(app_guid: app_in_space1.guid) }
    let!(:task2_in_space1) { TaskModel.make(app_guid: app_in_space1.guid) }
    let!(:task_for_app2) { TaskModel.make(app_guid: app2_in_space1.guid) }

    let(:app_in_space2) { AppModel.make }
    let!(:task_in_space2) { TaskModel.make(app_guid: app_in_space2.guid) }

    let(:pagination_options) { PaginationOptions.new({}) }
    subject(:fetcher) { described_class.new }

    describe '#fetch_all' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch(pagination_options, nil, nil)
        expect(results).to be_a(PaginatedResult)
      end

      it 'returns all of the tasks' do
        results = fetcher.fetch(pagination_options, nil, nil).records

        expect(results).to match_array([task_in_space1, task_for_app2, task2_in_space1, task_in_space2])
      end

      describe 'filtering by space' do
        it 'only returns tasks in those spaces' do
          results = fetcher.fetch(pagination_options, [space1.guid], nil).records

          expect(results).to match_array([task_in_space1, task2_in_space1, task_for_app2])
        end
      end

      describe 'filtering by app' do
        it 'only returns tasks for that app' do
          results = fetcher.fetch(pagination_options, nil, app_in_space1.guid).records

          expect(results).to match_array([task_in_space1, task2_in_space1])
        end
      end

      it 'can filter by spaces and app' do
        results = fetcher.fetch(pagination_options, [space1.guid], app_in_space1.guid).records

        expect(results).to match_array([task_in_space1, task2_in_space1])
      end
    end
  end
end
