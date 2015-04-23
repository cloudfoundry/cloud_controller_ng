require 'spec_helper'
require 'queries/process_scale_fetcher'

module VCAP::CloudController
  describe ProcessScaleFetcher do
    describe '#fetch' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let!(:process) { AppFactory.make(space: space) }

      subject(:process_scale_fetcher) { ProcessScaleFetcher.new }

      it 'returns the process, space, org' do
        actual_process, actual_space, actual_org = process_scale_fetcher.fetch(process.guid)
        expect(actual_process).to eq(process)
        expect(actual_space).to eq(space)
        expect(actual_org).to eq(org)
      end
    end
  end
end
