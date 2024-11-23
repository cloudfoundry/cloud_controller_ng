require 'spec_helper'
require 'cloud_controller/deployment_updater/actions/scale_down_old_process'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Actions::ScaleDownOldProcess do
    subject(:finalize_action) { DeploymentUpdater::Actions::ScaleDownOldProcess.new(deployment) }

    let(:app) { AppModel.make(revisions_enabled: true) }
    let(:droplet) { DropletModel.make(app: app, process_types: { 'web' => 'serve', 'worker' => 'work' }) }

    let(:state) { DeploymentModel::DEPLOYING_STATE }

    let!(:deploying_web_process) do
      ProcessModel.make(
        app: app,
        type: ProcessTypes::WEB,
        instances: 3
      )
    end

    let!(:interim_web_process) do
      ProcessModel.make(
        app: app,
        created_at: 1.hour.ago,
        type: ProcessTypes::WEB,
        instances: 3
      )
    end

    let!(:oldest_web_process) do
      ProcessModel.make(
        app: app,
        created_at: 2.days.ago,
        type: ProcessTypes::WEB,
        instances: 3
      )
    end

    let(:deployment) do
      DeploymentModel.make(
        app: app,
        deploying_web_process: deploying_web_process,
        state: state,
        original_web_process_instance_count: 3
      )
    end

    it 'scales a web process to the passed amount' do
      DeploymentUpdater::Actions::ScaleDownOldProcess.new(deployment, interim_web_process, 1).call
      expect(interim_web_process.reload.instances).to eq(1)
    end

    it 'deletes interim processes if they will have 0 instances' do
      DeploymentUpdater::Actions::ScaleDownOldProcess.new(deployment, interim_web_process, 3).call
      expect(ProcessModel.find(guid: interim_web_process.guid)).to be_nil
    end

    it 'does not delete the apps oldest web process' do
      DeploymentUpdater::Actions::ScaleDownOldProcess.new(deployment, oldest_web_process, 3).call
      expect(interim_web_process.reload.guid).to be_present
    end
  end
end
