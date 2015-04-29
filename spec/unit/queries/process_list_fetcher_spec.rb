require 'spec_helper'
require 'queries/process_list_fetcher'

module VCAP::CloudController
  describe ProcessListFetcher do
    describe '#fetch' do
      let(:space) { Space.make }
      let(:space_guids) { [space.guid] }
      let!(:process) { App.make(space: space) }
      let(:pagination_options) { PaginationOptions.new({}) }
      let(:fetcher) { described_class.new }

      describe '#fetch_all' do
        it 'returns a PaginatedResult' do
          results = fetcher.fetch_all(pagination_options)
          expect(results).to be_a(PaginatedResult)
        end

        it 'returns all of the processes' do
          App.make
          App.make
          App.make

          results = fetcher.fetch_all(pagination_options).records
          expect(results.length).to eq(App.count)
          expect(results).to include(process)
        end
      end

      describe '#fetch' do
        it 'returns a PaginatedResult' do
          results = fetcher.fetch(pagination_options, space_guids)
          expect(results).to be_a(PaginatedResult)
        end

        it 'returns only the processes in spaces requested' do
          process2 = App.make(space: space)
          App.make
          App.make

          results = fetcher.fetch(pagination_options, space_guids).records
          expect(results.length).to eq(App.where(space: Space.where(guid: space_guids)).count)
          expect(results.length).to be < (App.count)
          expect(results).to include(process)
          expect(results).to include(process2)
        end
      end
    end
  end
end
