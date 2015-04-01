require 'spec_helper'
require 'queries/app_delete_fetcher'

module VCAP::CloudController
  describe AppDeleteFetcher do
    describe '#fetch' do
      let(:app_model) { AppModel.make }

      subject(:app_delete_fetcher) { AppDeleteFetcher.new }

      it 'returns the app, nothing else' do
        expect(app_delete_fetcher.fetch(app_model.guid)).to include(app_model)
      end
    end
  end
end
