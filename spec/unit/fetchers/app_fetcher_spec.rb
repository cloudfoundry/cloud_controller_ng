require 'spec_helper'
require 'fetchers/app_fetcher'

module VCAP::CloudController
  RSpec.describe AppFetcher do
    describe '#fetch' do
      let(:app) { AppModel.make }
      let(:space) { app.space }

      it 'returns the desired app and space' do
        returned_app, returned_space = AppFetcher.new.fetch(app.guid)
        expect(returned_app).to eq(app)
        expect(returned_space).to eq(space)
      end

      context 'when the app is not found' do
        it 'returns nil' do
          returned_app, returned_space = AppFetcher.new.fetch('bogus-guid')
          expect(returned_app).to be_nil
          expect(returned_space).to be_nil
        end
      end
    end
  end
end
