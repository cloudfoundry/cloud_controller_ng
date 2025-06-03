require 'spec_helper'
require 'cloud_controller/deployment_updater/actions/scale_down_canceled_processes'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Actions::ScaleDownCanceledProcesses do
    subject(:finalize_action) { DeploymentUpdater::Actions::ScaleDownCanceledProcesses.new(deployment) }

    let(:app) { AppModel.make(revisions_enabled: true) }
    let(:droplet) { DropletModel.make(app: app, process_types: { 'web' => 'serve', 'worker' => 'work' }) }

    let(:state) { DeploymentModel::DEPLOYING_STATE }

    let!(:deploying_web_process) do
      ProcessModel.make(
        app: app,
        type: ProcessTypes::WEB,
        instances: 3,
        guid: 'guid-final',
        state: ProcessModel::STOPPED
      )
    end

    let!(:interim_canceling_web_process) do
      ProcessModel.make(
        app: app,
        created_at: 1.hour.ago,
        type: ProcessTypes::WEB,
        instances: 1,
        guid: 'guid-canceling'
      )
    end

    let(:deployment) do
      DeploymentModel.make(
        app: app,
        deploying_web_process: deploying_web_process,
        state: state,
        original_web_process_instance_count: 3,
        max_in_flight: 1
      )
    end

    let!(:interim_canceled_superseded_deployment) do
      DeploymentModel.make(
        deploying_web_process: interim_canceling_web_process,
        state: 'CANCELED',
        status_reason: 'SUPERSEDED'
      )
    end

    context 'when there is an interim deployment that has been SUPERSEDED (CANCELED)' do
      it 'scales the canceled web process to zero' do
        subject.call
        expect(interim_canceling_web_process.reload.instances).to eq(0)
      end
    end
  end
end
