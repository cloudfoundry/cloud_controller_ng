require 'spec_helper'

module VCAP::CloudController
  RSpec.describe TaskListFetcher do
    let(:space1) { Space.make }
    let(:app_in_space1) { AppModel.make(space_guid: space1.guid) }
    let(:app2_in_space1) { AppModel.make(space_guid: space1.guid) }

    let!(:task_in_space1) { TaskModel.make(app_guid: app_in_space1.guid) }
    let!(:task2_in_space1) { TaskModel.make(app_guid: app_in_space1.guid) }
    let!(:task_for_app2) { TaskModel.make(app_guid: app2_in_space1.guid) }

    let!(:label_for_task_in_space1) { TaskLabelModel.make(resource_guid: task_in_space1.guid, key_name: 'key', value: 'value') }
    let!(:label_for_task_in_space1_jr) { TaskLabelModel.make(resource_guid: task_in_space1.guid, key_name: 'key2', value: 'slimjim') }

    let(:space2) { Space.make }
    let(:app_in_space2) { AppModel.make(space_guid: space2.guid) }
    let!(:task_in_space2) { TaskModel.make(app_guid: app_in_space2.guid) }
    let!(:failed_task_in_space2) { TaskModel.make(app_guid: app_in_space2.guid, state: TaskModel::FAILED_STATE) }

    let!(:label_for_task_in_space2) { TaskLabelModel.make(resource_guid: task_in_space2.guid, key_name: 'key', value: 'value') }

    let(:org2) { Organization.make }
    let(:space_in_org2) { Space.make(organization_guid: org2.guid) }
    let(:app_in_org2) { AppModel.make(space_guid: space_in_org2.guid) }
    let!(:task_in_org2) { TaskModel.make(app_guid: app_in_org2.guid) }

    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { TasksListMessage.from_params(filters) }
    let(:filters) { {} }

    subject(:fetcher) { TaskListFetcher }

    results = nil

    describe '#fetch_all' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all(message:)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns all of the tasks' do
        results = fetcher.fetch_all(message:).all

        expect(results).to contain_exactly(task_in_space1, task_for_app2, task2_in_space1, task_in_space2, failed_task_in_space2, task_in_org2)
      end

      describe 'filtering on message' do
        before do
          results = fetcher.fetch_all(message:).all
        end

        context 'when task names are provided' do
          let(:filters) { { names: [task_in_space1.name, task_in_space2.name] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(task_in_space1, task_in_space2)
          end
        end

        context 'when task states are provided' do
          let(:filters) { { states: ['FAILED'] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(failed_task_in_space2)
          end
        end

        context 'when task guids are provided' do
          let(:filters) { { guids: [task_in_space1.guid, task_in_space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(task_in_space1, task_in_space2)
          end
        end

        context 'when app guids are provided' do
          let(:filters) { { app_guids: [app2_in_space1.guid, app_in_space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(task_for_app2, failed_task_in_space2, task_in_space2)
          end
        end

        context 'when space guids are provided' do
          let(:filters) { { space_guids: [space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(failed_task_in_space2, task_in_space2)
          end
        end

        context 'when org guids are provided' do
          let(:filters) { { organization_guids: [org2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(task_in_org2)
          end
        end

        context 'filtering label selectors' do
          let(:filters) { { 'label_selector' => 'key=value' } }

          it 'returns the correct set of tasks' do
            expect(results.size).to eq(2)
            expect(results).to contain_exactly(task_in_space1, task_in_space2)
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

        expect(results).to contain_exactly(task_in_space1, task2_in_space1, task_for_app2, task_in_space2, failed_task_in_space2)
      end

      describe 'filtering on message' do
        before do
          results = fetcher.fetch_for_spaces(message: message, space_guids: [space2.guid]).all
        end

        context 'when task names are provided' do
          let(:filters) { { names: [task_in_space1.name, task_in_space2.name] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(task_in_space2)
          end
        end

        context 'when task states are provided' do
          let(:filters) { { states: ['FAILED'] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(failed_task_in_space2)
          end
        end

        context 'when task guids are provided' do
          let(:filters) { { guids: [task_in_space1.guid, task_in_space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(task_in_space2)
          end
        end

        context 'when app guids are provided' do
          let(:filters) { { app_guids: [app2_in_space1.guid, app_in_space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(failed_task_in_space2, task_in_space2)
          end
        end

        context 'when space guids are provided' do
          let(:filters) { { space_guids: [space2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to contain_exactly(failed_task_in_space2, task_in_space2)
          end
        end

        context 'when org guids are provided' do
          let(:filters) { { organization_guids: [org2.guid] } }

          it 'returns the correct set of tasks' do
            expect(results).to be_empty
          end
        end

        context 'filtering label selectors' do
          let(:filters) { { 'label_selector' => 'key=value' } }

          it 'returns the correct set of tasks' do
            expect(results.size).to eq(1)
            expect(results).to contain_exactly(task_in_space2)
          end
        end
      end
    end

    describe '#fetch_for_app' do
      let(:filters) { { app_guid: app_in_space1.guid } }

      it 'returns a Sequel::Dataset' do
        _app, results = fetcher.fetch_for_app(message:)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'only returns tasks for that app' do
        _app, results = fetcher.fetch_for_app(message:)
        expect(results.all).to contain_exactly(task_in_space1, task2_in_space1)
      end

      it 'returns the app' do
        returned_app, results = fetcher.fetch_for_app(message:)
        expect(returned_app.guid).to eq(app_in_space1.guid)
      end

      context 'when the app does not exist' do
        let(:filters) { { app_guid: 'made up' } }

        it 'returns nil' do
          returned_app, results = fetcher.fetch_for_app(message:)
          expect(returned_app).to be_nil
          expect(results).to be_nil
        end
      end

      describe 'filtering on message' do
        before do
          _app, results = fetcher.fetch_for_app(message:)
        end

        context 'when task names are provided' do
          let(:filters) { { names: [task_in_space1.name, task_in_space2.name], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to contain_exactly(task_in_space1)
          end

          it 'generates a SQL query with the correct structure (without an inner select)' do
            expect(results.count('SELECT')).to eq 1
          end
        end

        context 'when task states are provided' do
          let(:filters) { { states: ['FAILED'], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to be_empty
          end
        end

        context 'when task guids are provided' do
          let(:filters) { { guids: [task_in_space1.guid, task_in_space2.guid], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to contain_exactly(task_in_space1)
          end
        end

        context 'when space guids are provided' do
          let(:filters) { { space_guids: [space2.guid], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to be_empty
          end
        end

        context 'when org guids are provided' do
          let(:filters) { { organization_guids: [org2.guid], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to be_empty
          end
        end

        context 'when sequence_ids are provided' do
          let(:filters) { { sequence_ids: [task2_in_space1.sequence_id], app_guid: app_in_space1.guid } }

          it 'returns the correct set of tasks' do
            expect(results.all).to contain_exactly(task2_in_space1)
          end
        end

        context 'filtering label selectors' do
          context 'in space 1' do
            let(:filters) { { 'label_selector' => 'key=value', 'app_guid' => app_in_space1.guid } }

            it 'returns the correct set of tasks' do
              expect(results.count).to eq(1)
              expect(results.all).to contain_exactly(task_in_space1)
            end
          end

          context 'in space 2' do
            let(:filters) { { 'label_selector' => 'key2=slimjim', 'app_guid' => app_in_space2.guid } }

            it 'returns the correct set of tasks' do
              expect(results.count).to eq(0)
            end
          end
        end
      end
    end
  end
end
