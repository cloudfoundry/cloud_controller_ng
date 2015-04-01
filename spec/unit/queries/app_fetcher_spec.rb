require 'spec_helper'
require 'queries/app_fetcher'

module VCAP::CloudController
  describe AppFetcher do
    describe '#fetch' do
      let(:app_model) { AppModel.make }

      it 'returns the desired app' do
        expect(AppFetcher.new.fetch(app_model.guid)).to eq(app_model)
      end
    end
  end
end
