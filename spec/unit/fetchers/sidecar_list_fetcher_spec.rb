require 'spec_helper'
require 'messages/sidecars_list_message'
require 'fetchers/sidecar_list_fetcher'

module VCAP::CloudController
  RSpec.describe SidecarListFetcher do
    subject { SidecarListFetcher.fetch(message) }
    let(:fetcher) { SidecarListFetcher }
    let(:filters) { {} }
    let(:message) { SidecarsListMessage.from_params(filters) }
    let(:app_model) { create(:app_model) }

    describe '#fetch_for_app' do
      let!(:sidecar1) { create(:sidecar_model, app: app_model) }
      let!(:sidecar2) { create(:sidecar_model, app: app_model) }
      let!(:sidecar3) { create(:sidecar_model, app: create(:app_model)) }

      it 'successfully loads sidecars' do
        app, results = fetcher.fetch_for_app(message, app_model.guid)

        expect(app).to eq(app_model)
        expect(results).to contain_exactly(sidecar1, sidecar2)
      end

      context 'when the app does not exist' do
        it 'returns nil for the app' do
          app, results = fetcher.fetch_for_app(message, 'non-existant-app-guid')

          expect(app).to be_nil
          expect(results).to be_nil
        end
      end
    end

    describe '#fetch_for_process' do
      let!(:sidecar1a) { create(:sidecar_model, app: app_model) }
      let!(:sidecar1b) { create(:sidecar_model, app: app_model) }
      let!(:sidecar2) { create(:sidecar_model, app: app_model) }

      let!(:web_process) do
        create(:process_model,
               :process,
               app: app_model,
               type: 'web',
               command: 'rackup')
      end
      let!(:worker_process) do
        create(:process_model,
               :process,
               app: app_model,
               type: 'worker',
               command: 'rackup')
      end

      before do
        create(:sidecar_process_type_model, sidecar: sidecar1a, type: 'web')
        create(:sidecar_process_type_model, sidecar: sidecar1b, type: 'web')
        create(:sidecar_process_type_model, sidecar: sidecar2, type: 'worker')
      end

      it 'successfully loads web sidecars' do
        process, results = fetcher.fetch_for_process(message, web_process.guid)

        expect(process).to eq(web_process)
        expect(results).to contain_exactly(sidecar1a, sidecar1b)
      end

      it 'successfully loads worker sidecars' do
        process, results = fetcher.fetch_for_process(message, worker_process.guid)

        expect(process).to eq(worker_process)
        expect(results).to contain_exactly(sidecar2)
      end

      context 'when the process does not exist' do
        it 'returns nil for the app' do
          process, results = fetcher.fetch_for_process(message, 'non-existant-process-guid')

          expect(process).to be_nil
          expect(results).to be_nil
        end
      end
    end
  end
end
