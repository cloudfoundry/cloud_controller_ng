require 'spec_helper'
require 'queries/app_fetcher'

module VCAP::CloudController
  describe AppFetcher do
    describe '#fetch' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:org) { space.organization }

      it 'returns the desired app, space, org' do
        returned_app, returned_space, returned_org = AppFetcher.new.fetch(app.guid)
        expect(returned_app).to eq(app)
        expect(returned_space).to eq(space)
        expect(returned_org).to eq(org)
      end

      context 'when the app is not found' do
        it 'returns nil' do
          returned_app, returned_space, returned_org = AppFetcher.new.fetch('bogus-guid')
          expect(returned_app).to be_nil
          expect(returned_space).to be_nil
          expect(returned_org).to be_nil
        end
      end
    end
  end
end
