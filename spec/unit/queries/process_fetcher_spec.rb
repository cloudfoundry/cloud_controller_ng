require 'spec_helper'
require 'queries/process_fetcher'

module VCAP::CloudController
  describe ProcessFetcher do
    subject(:fetcher) { described_class.new }

    describe '#fetch' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let!(:process) { App.make(space: space) }

      it 'returns the process, space, org' do
        actual_process, actual_space, actual_org = fetcher.fetch(process_guid: process.guid)
        expect(actual_process).to eq(process)
        expect(actual_space).to eq(space)
        expect(actual_org).to eq(org)
      end

      context 'when the process does not exist' do
        it 'returns nil' do
          actual_process, actual_space, actual_org = fetcher.fetch(process_guid: 'made-up')
          expect(actual_process).to be_nil
          expect(actual_space).to be_nil
          expect(actual_org).to be_nil
        end
      end
    end

    describe '#fetch_for_app_by_type' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:org) { app.organization }
      let!(:process) { App.make(app_guid: app.guid) }

      it 'returns the process, app, space, org' do
        actual_process, actual_app, actual_space, actual_org = fetcher.fetch_for_app_by_type(process_type: process.type, app_guid: app.guid)
        expect(actual_process).to eq(process)
        expect(actual_app).to eq(app)
        expect(actual_space).to eq(space)
        expect(actual_org).to eq(org)
      end

      context 'when the app does not exist' do
        it 'returns nil' do
          actual_process, actual_app, actual_space, actual_org = fetcher.fetch_for_app_by_type(process_type: process.type, app_guid: 'no-app')
          expect(actual_process).to be_nil
          expect(actual_app).to be_nil
          expect(actual_space).to be_nil
          expect(actual_org).to be_nil
        end
      end
    end
  end
end
