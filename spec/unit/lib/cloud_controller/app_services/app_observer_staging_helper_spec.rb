require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppObserverStagingHelper do
    let(:package) { PackageModel.make(state: PackageModel::READY_STATE) }
    let(:app) { App.make(app: package.app, memory: 10, disk_quota: 30) }
    let(:droplet_creator) { instance_double(DropletCreate, create_and_stage: nil, staging_response: 'staging-response') }

    before do
      allow(DropletCreate).to receive(:new).and_return(droplet_creator)
    end

    it 'builds the correct DropletCreateMessage' do
      allow(DropletCreateMessage).to receive(:new).and_call_original

      AppObserverStagingHelper.stage_app(app)

      expect(DropletCreateMessage).to have_received(:new).with(
        {
          staging_memory_in_mb: 10,
          staging_disk_in_mb:   30,
        }
      )
    end

    it 'passes the package to LifecycleProvider' do
      allow(LifecycleProvider).to receive(:provide)
      AppObserverStagingHelper.stage_app(app)
      expect(LifecycleProvider).to have_received(:provide).with(package, anything)
    end

    it 'stages the package' do
      AppObserverStagingHelper.stage_app(app)
      expect(droplet_creator).to have_received(:create_and_stage)
    end

    it 'sets last_stager_response on the app' do
      expect { AppObserverStagingHelper.stage_app(app) }.to change { app.last_stager_response }.to('staging-response')
    end
  end
end
