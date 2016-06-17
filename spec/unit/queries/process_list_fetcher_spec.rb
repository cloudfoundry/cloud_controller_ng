require 'spec_helper'
require 'queries/process_list_fetcher'

module VCAP::CloudController
  RSpec.describe ProcessListFetcher do
    let(:fetcher) { described_class.new(message) }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { ProcessesListMessage.new(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      let!(:web) { App.make(type: 'web') }
      let!(:web2) { App.make(type: 'web') }
      let!(:worker) { App.make(type: 'worker') }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns all of the processes' do
        results = fetcher.fetch_all.all
        expect(results).to match_array([web, web2, worker])
      end

      context 'filters' do
        context 'type' do
          let(:filters) { { types: ['web'] } }

          it 'only returns matching processes' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([web, web2])
          end
        end

        context 'space guids' do
          let(:filters) { { space_guids: [web.space.guid] } }

          it 'only returns matching processes' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([web])
          end
        end

        context 'organization guids' do
          let(:filters) { { organization_guids: [web.space.organization.guid] } }

          it 'only returns matching processes' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([web])
          end
        end

        context 'app guids' do
          let!(:desired_process) { App.make(app: desired_app) }
          let(:desired_app) { AppModel.make }
          let(:filters) { { app_guids: [desired_app.guid] } }

          it 'only returns matching processes' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([desired_process])
          end
        end

        context 'guids' do
          let(:filters) { { guids: [web.guid, web2.guid] } }

          it 'returns the matching processes' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([web, web2])
          end
        end
      end
    end

    describe '#fetch_for_spaces' do
      let(:space1) { Space.make }
      let!(:process_in_space1) { App.make(space: space1) }
      let!(:process2_in_space1) { App.make(space: space1) }
      let(:space2) { Space.make }
      let!(:process_in_space2) { App.make(space: space2) }

      before { App.make }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_for_spaces(space_guids: [])
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns only the processes in spaces requested' do
        results = fetcher.fetch_for_spaces(space_guids: [space1.guid, space2.guid]).all
        expect(results).to match_array([process_in_space1, process2_in_space1, process_in_space2])
      end

      context 'with a space_guid filter' do
        let(:filters) { { space_guids: [space1.guid] } }

        it 'only returns matching processes' do
          results = fetcher.fetch_for_spaces(space_guids: [space1.guid, space2.guid]).all
          expect(results).to match_array([process_in_space1, process2_in_space1])
        end
      end
    end

    describe '#fetch_for_app' do
      let(:app) { AppModel.make }
      let(:filters) { { app_guid: app.guid } }

      it 'returns a Sequel::Dataset and the app' do
        returned_app, results = fetcher.fetch_for_app
        expect(returned_app.guid).to eq(app.guid)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns the processes for the app' do
        process1 = App.make(app: app)
        process2 = App.make(app: app)
        App.make

        _app, results = fetcher.fetch_for_app
        expect(results.all).to match_array([process1, process2])
      end

      context 'when the app does not exist' do
        let(:filters) { { app_guid: 'made-up' } }

        it 'returns nil' do
          returned_app, results = fetcher.fetch_for_app
          expect(returned_app).to be_nil
          expect(results).to be_nil
        end
      end
    end
  end
end
