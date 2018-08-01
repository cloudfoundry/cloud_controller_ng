require 'spec_helper'

module VCAP::CloudController
  RSpec.describe TaskListFetcher do
    let(:space1) { Space.make }
    let(:app_in_space1) { AppModel.make(space_guid: space1.guid) }
    let(:app2_in_space1) { AppModel.make(space_guid: space1.guid) }

    let!(:task_in_space1) { TaskModel.make(app_guid: app_in_space1.guid) }
    let!(:task2_in_space1) { TaskModel.make(app_guid: app_in_space1.guid) }
    let!(:task_for_app2) { TaskModel.make(app_guid: app2_in_space1.guid) }

    let(:space2) { Space.make }
    let(:app_in_space2) { AppModel.make(space_guid: space2.guid) }
    let!(:task_in_space2) { TaskModel.make(app_guid: app_in_space2.guid) }
    let!(:failed_task_in_space2) { TaskModel.make(app_guid: app_in_space2.guid, state: TaskModel::FAILED_STATE) }

    let(:org2) { Organization.make }
    let(:space_in_org2) { Space.make(organization_guid: org2.guid) }
    let(:app_in_org2) { AppModel.make(space_guid: space_in_org2.guid) }
    let!(:task_in_org2) { TaskModel.make(app_guid: app_in_org2.guid) }

    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { TasksListMessage.new(filters) }
    let(:filters) { {} }
    subject(:fetcher) { described_class.new }

    results = nil

    describe '#fetch_all' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all(message: message)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns all of the tasks' do
        results = fetcher.fetch_all(message: message).all

        expect(results).to match_array([task_in_space1, task_for_app2, task2_in_space1, task_in_space2, failed_task_in_space2, task_in_org2])
      end

      describe 'filtering on message' do
        before do
          results = fetcher.fetch_all(message: message).all
        end

        context 'when task names are provided' do
          let(:filters) { { names: [task_in_space1.name, task_in_space2.name] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([task_in_space1, task_in_space2])
          end
        end

        context 'when task states are provided' do
          let(:filters) { { states: ['FAILED'] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([failed_task_in_space2])
          end
        end

        context 'when task guids are provided' do
          let(:filters) { { guids: [task_in_space1.guid, task_in_space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([task_in_space1, task_in_space2])
          end
        end

        context 'when app guids are provided' do
          let(:filters) { { app_guids: [app2_in_space1.guid, app_in_space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([task_for_app2, failed_task_in_space2, task_in_space2])
          end
        end

        context 'when space guids are provided' do
          let(:filters) { { space_guids: [space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([failed_task_in_space2, task_in_space2])
          end
        end

        context 'when org guids are provided' do
          let(:filters) { { organization_guids: [org2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([task_in_org2])
          end
        end
      end
    end

    describe '#fetch_for_spaces' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_for_spaces(message: message, space_guids: [])
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'only returns tasks in those spaces' do
        results = fetcher.fetch_for_spaces(message: message, space_guids: [space1.guid, space2.guid]).all

        expect(results).to match_array([
          task_in_space1,
          task2_in_space1,
          task_for_app2,
          task_in_space2,
          failed_task_in_space2
        ])
      end

      describe 'filtering on message' do
        before do
          results = fetcher.fetch_for_spaces(message: message, space_guids: [space2.guid]).all
        end

        context 'when task names are provided' do
          let(:filters) { { names: [task_in_space1.name, task_in_space2.name] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([task_in_space2])
          end
        end

        context 'when task states are provided' do
          let(:filters) { { states: ['FAILED'] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([failed_task_in_space2])
          end
        end

        context 'when task guids are provided' do
          let(:filters) { { guids: [task_in_space1.guid, task_in_space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([task_in_space2])
          end
        end

        context 'when app guids are provided' do
          let(:filters) { { app_guids: [app2_in_space1.guid, app_in_space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([failed_task_in_space2, task_in_space2])
          end
        end

        context 'when space guids are provided' do
          let(:filters) { { space_guids: [space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([failed_task_in_space2, task_in_space2])
          end
        end

        context 'when org guids are provided' do
          let(:filters) { { organization_guids: [org2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to match_array([])
          end
        end
      end
    end

    describe '#fetch_for_app' do
      let(:filters) { { app_guid: app_in_space1.guid } }

      it 'returns a Sequel::Dataset' do
        _app, results = fetcher.fetch_for_app(message: message)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'only returns tasks for that app' do
        _app, results = fetcher.fetch_for_app(message: message)
        expect(results.all).to match_array([task_in_space1, task2_in_space1])
      end

      it 'returns the app' do
        returned_app, results = fetcher.fetch_for_app(message: message)
        expect(returned_app.guid).to eq(app_in_space1.guid)
      end

      context 'when the app does not exist' do
        let(:filters) { { app_guid: 'made up' } }

        it 'returns nil' do
          returned_app, results = fetcher.fetch_for_app(message: message)
          expect(returned_app).to be_nil
          expect(results).to be_nil
        end
      end

      describe 'filtering on message' do
        before do
          _app, results = fetcher.fetch_for_app(message: message)
        end

        context 'when task names are provided' do
          let(:filters) { { names: [task_in_space1.name, task_in_space2.name], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to match_array([task_in_space1])
          end
        end

        context 'when task states are provided' do
          let(:filters) { { states: ['FAILED'], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to match_array([])
          end
        end

        context 'when task guids are provided' do
          let(:filters) { { guids: [task_in_space1.guid, task_in_space2.guid], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to match_array([task_in_space1])
          end
        end

        context 'when space guids are provided' do
          let(:filters) { { space_guids: [space2.guid], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to match_array([])
          end
        end

        context 'when org guids are provided' do
          let(:filters) { { organization_guids: [org2.guid], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to match_array([])
          end
        end

        context 'when sequence_ids are provided' do
          let(:filters) { { sequence_ids: [task2_in_space1.sequence_id], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to match_array([task2_in_space1])
          end
        end
      end
    end
  end
end
