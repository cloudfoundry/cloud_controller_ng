require 'spec_helper'
require 'messages/sidecars_list_message'
require 'fetchers/sidecar_list_fetcher'

module VCAP::CloudController
  RSpec.describe SidecarListFetcher do
    subject { SidecarListFetcher.fetch(message) }
    let(:fetcher) { SidecarListFetcher }
    let(:filters) { {} }
    let(:message) { SidecarsListMessage.from_params(filters) }
    let(:app_model) { AppModel.make }

    describe '#fetch_for_app' do
      let!(:sidecar1) { SidecarModel.make(app: app_model) }
      let!(:sidecar2) { SidecarModel.make(app: app_model) }
      let!(:sidecar3) { SidecarModel.make(app: AppModel.make) }

      it 'successfully loads sidecars' do
        app, results = fetcher.fetch_for_app(message, app_model.guid)

        expect(app).to eq(app_model)
        expect(results).to contain_exactly(sidecar1, sidecar2)
      end
    end

    describe '#fetch_for_process' do
      let!(:sidecar1a) { SidecarModel.make(app: app_model) }
      let!(:sidecar1b) { SidecarModel.make(app: app_model) }
      let!(:sidecar2) { SidecarModel.make(app: app_model) }

      let!(:web_process) { ProcessModel.make(
        :process,
        app:        app_model,
        type:       'web',
        command:    'rackup',
      )
      }
      let!(:worker_process) { ProcessModel.make(
        :process,
        app:        app_model,
        type:       'worker',
        command:    'rackup',
      )
      }

      before do
        SidecarProcessTypeModel.make(sidecar: sidecar1a, type: 'web')
        SidecarProcessTypeModel.make(sidecar: sidecar1b, type: 'web')
        SidecarProcessTypeModel.make(sidecar: sidecar2, type: 'worker')
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
    end
  end
end
