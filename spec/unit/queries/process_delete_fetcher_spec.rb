require 'spec_helper'
require 'queries/process_delete_fetcher'

module VCAP::CloudController
  describe ProcessDeleteFetcher do
    describe '#fetch' do
      let(:space) { Space.make }
      let!(:process) { AppFactory.make(space: space) }

      subject(:process_delete_fetcher) { ProcessDeleteFetcher.new }

      it 'returns the process and the space' do
        process_dataset, actual_space = process_delete_fetcher.fetch(process.guid)
        expect(process_dataset).to include(process)
        expect(actual_space).to eq(space)
      end
    end
  end
end
