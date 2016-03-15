require 'spec_helper'
require 'queries/process_list_fetcher'

module VCAP::CloudController
  describe ProcessListFetcher do
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:fetcher) { described_class.new }

    describe '#fetch_all' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch_all(pagination_options: pagination_options)
        expect(results).to be_a(PaginatedResult)
      end

      it 'returns all of the processes' do
        app1 = App.make
        app2 = App.make
        app3 = App.make

        results = fetcher.fetch_all(pagination_options: pagination_options).records
        expect(results).to match_array([app1, app2, app3])
      end
    end

    describe '#fetch_for_spaces' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch_for_spaces(pagination_options: pagination_options, space_guids: [])
        expect(results).to be_a(PaginatedResult)
      end

      it 'returns only the processes in spaces requested' do
        space1             = Space.make
        process1_in_space1 = App.make(space: space1)
        process2_in_space1 = App.make(space: space1)

        space2             = Space.make
        process1_in_space2 = App.make(space: space2)

        App.make

        results = fetcher.fetch_for_spaces(pagination_options: pagination_options, space_guids: [space1.guid, space2.guid]).records
        expect(results).to match_array([process1_in_space1, process2_in_space1, process1_in_space2])
      end
    end

    describe '#fetch_for_app' do
      let(:app) { AppModel.make }

      it 'returns a PaginatedResult and the app' do
        returned_app, results = fetcher.fetch_for_app(app_guid: app.guid, pagination_options: pagination_options)
        expect(returned_app.guid).to eq(app.guid)
        expect(results).to be_a(PaginatedResult)
      end

      it 'returns the processes for the app' do
        process1 = App.make(app: app)
        process2 = App.make(app: app)
        App.make

        _app, results = fetcher.fetch_for_app(app_guid: app.guid, pagination_options: pagination_options)
        expect(results.records).to match_array([process1, process2])
      end

      context 'when the app does not exist' do
        it 'returns nil' do
          returned_app, results = fetcher.fetch_for_app(app_guid: 'made-up', pagination_options: pagination_options)
          expect(returned_app).to be_nil
          expect(results).to be_nil
        end
      end
    end
  end
end
