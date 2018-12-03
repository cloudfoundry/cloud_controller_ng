require 'spec_helper'
require 'fetchers/process_fetcher'

module VCAP::CloudController
  RSpec.describe ProcessFetcher do
    subject(:fetcher) { ProcessFetcher }

    describe '.fetch' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:org) { app.organization }
      let!(:process) { ProcessModel.make(app: app) }

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

    describe 'fetch_for_app_by_type' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:org) { app.organization }
      let!(:process) { ProcessModel.make(app: app) }

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

      context 'when there are multiple matching processes by type' do
        let!(:process_2) { ProcessModel.make(app: app, guid: 'process_2', created_at: process.created_at) }
        let!(:process_3) { ProcessModel.make(app: app, guid: 'process_3', created_at: process.created_at + 2) }
        let!(:process_4) { ProcessModel.make(app: app, guid: 'process_4', created_at: process.created_at + 3) }
        let!(:process_5) { ProcessModel.make(app: app, guid: 'process_5', created_at: process.created_at + 2) }

        it 'returns the newest one' do
          actual_process, actual_app, actual_space, actual_org = fetcher.fetch_for_app_by_type(process_type: process.type, app_guid: app.guid)
          expect(actual_process).to eq(process_4)
          expect(actual_app).to eq(app)
          expect(actual_space).to eq(space)
          expect(actual_org).to eq(org)
        end
      end

      context 'when multiple matching processes were created simultaneously' do
        let!(:process_2) { ProcessModel.make(app: app, guid: 'process_2', created_at: process.created_at) }
        let!(:process_3) { ProcessModel.make(app: app, guid: 'process_3', created_at: process.created_at) }

        it 'returns the one with the higher id' do
          actual_process, actual_app, actual_space, actual_org = fetcher.fetch_for_app_by_type(process_type: process.type, app_guid: app.guid)
          expect(actual_process).to eq(process_3)
          expect(actual_app).to eq(app)
          expect(actual_space).to eq(space)
          expect(actual_org).to eq(org)
        end
      end
    end
  end
end
