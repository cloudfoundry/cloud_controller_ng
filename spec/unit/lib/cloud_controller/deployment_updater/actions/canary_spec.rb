require 'spec_helper'
require 'cloud_controller/deployment_updater/actions/canary'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Actions::Canary do
    subject(:canary_action) { DeploymentUpdater::Actions::Canary.new(deployment, logger) }
    let(:a_day_ago) { Time.now - 1.day }
    let(:an_hour_ago) { Time.now - 1.hour }
    let(:app) { AppModel.make(droplet: droplet, revisions_enabled: true) }
    let(:droplet) { DropletModel.make }
    let!(:web_process) do
      ProcessModel.make(
        instances: current_web_instances,
        created_at: a_day_ago,
        guid: 'guid-original',
        app: app
      )
    end
    let!(:route_mapping) { RouteMappingModel.make(app: web_process.app, process_type: web_process.type) }
    let!(:deploying_web_process) do
      ProcessModel.make(
        app: web_process.app,
        type: ProcessTypes::WEB,
        instances: current_deploying_instances,
        guid: 'guid-final',
        revision: revision,
        state: ProcessModel::STOPPED
      )
    end
    let(:revision) { RevisionModel.make(app: app, droplet: droplet, version: 300) }
    let!(:deploying_route_mapping) { RouteMappingModel.make(app: web_process.app, process_type: deploying_web_process.type) }
    let(:space) { web_process.space }
    let(:original_web_process_instance_count) { 6 }
    let(:current_web_instances) { 2 }

    let(:state) { DeploymentModel::PREPAUSED_STATE }
    let(:current_deploying_instances) { 1 }

    let(:deployment) do
      DeploymentModel.make(
        app: web_process.app,
        deploying_web_process: deploying_web_process,
        state: state,
        original_web_process_instance_count: original_web_process_instance_count,
        max_in_flight: 1
      )
    end

    let(:diego_instances_reporter) { instance_double(Diego::InstancesReporter) }
    let(:all_instances_results) do
      {
        0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
        1 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
        2 => { state: 'RUNNING', uptime: 50, since: 2, routable: true }
      }
    end
    let(:instances_reporters) { double(:instance_reporters) }
    let(:logger) { instance_double(Steno::Logger, info: nil, error: nil) }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
      allow(instances_reporters).to receive(:all_instances_for_app).and_return(all_instances_results)
    end

    it 'locks the deployment' do
      allow(deployment).to receive(:lock!).and_call_original
      subject.call
      expect(deployment).to have_received(:lock!)
    end

    context 'when the canary instance starts succesfully' do
      let(:all_instances_results) do
        {
          0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true }
        }
      end

      it 'pauses the deployment' do
        subject.call
        expect(deployment.state).to eq(DeploymentModel::PAUSED_STATE)
        expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
        expect(deployment.status_reason).to eq(DeploymentModel::PAUSED_STATUS_REASON)
      end

      it 'updates last_healthy_at' do
        previous_last_healthy_at = deployment.last_healthy_at
        Timecop.travel(deployment.last_healthy_at + 10.seconds) do
          subject.call
          expect(deployment.reload.last_healthy_at).to be > previous_last_healthy_at
        end
      end

      it 'does not alter the existing web processes' do
        expect do
          subject.call
        end.not_to(change do
          web_process.reload.instances
        end)
      end

      it 'logs the canary is paused' do
        subject.call
        expect(logger).to have_received(:info).with(
          "paused-canary-deployment-for-#{deployment.guid}"
        )
      end
    end

    context 'while the canary instance is still starting' do
      let(:all_instances_results) do
        {
          0 => { state: 'STARTING', uptime: 50, since: 2, routable: true }
        }
      end

      it 'skips the deployment update' do
        subject.call
        expect(deployment.state).to eq(DeploymentModel::PREPAUSED_STATE)
        expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
        expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYING_STATUS_REASON)
      end
    end

    context 'when the canary is not routable routable' do
      let(:all_instances_results) do
        {
          0 => { state: 'RUNNING', uptime: 50, since: 2, routable: false }
        }
      end

      it 'skips the deployment update' do
        subject.call
        expect(deployment.state).to eq(DeploymentModel::PREPAUSED_STATE)
        expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
        expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYING_STATUS_REASON)
      end
    end

    context 'when the canary instance is failing' do
      let(:all_instances_results) do
        {
          0 => { state: 'FAILING', uptime: 50, since: 2, routable: true }
        }
      end

      it 'does not update the deployments last_healthy_at' do
        Timecop.travel(Time.now + 1.minute) do
          expect do
            subject.call
          end.not_to(change { deployment.reload.last_healthy_at })
        end
      end

      it 'changes nothing' do
        previous_last_healthy_at = deployment.last_healthy_at
        subject.call
        expect(deployment.reload.last_healthy_at).to eq previous_last_healthy_at
        expect(deployment.state).to eq(DeploymentModel::PREPAUSED_STATE)
        expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
        expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYING_STATUS_REASON)
      end
    end

    context 'when there is an interim deployment that has been SUPERSEDED (CANCELED)' do
      let!(:interim_canceling_web_process) do
        ProcessModel.make(
          app: app,
          created_at: an_hour_ago,
          type: ProcessTypes::WEB,
          instances: 1,
          guid: 'guid-canceling'
        )
      end
      let!(:interim_canceled_superseded_deployment) do
        DeploymentModel.make(
          deploying_web_process: interim_canceling_web_process,
          state: 'CANCELED',
          status_reason: 'SUPERSEDED'
        )
      end

      it 'scales the canceled web process to zero' do
        subject.call
        expect(interim_canceling_web_process.reload.instances).to eq(0)
      end
    end

    context 'when this deployment got superseded' do
      before do
        deployment.update(state: 'DEPLOYED', status_reason: 'SUPERSEDED')

        allow(deployment).to receive(:update).and_call_original
      end

      it 'skips the deployment update' do
        subject.call
        expect(deployment).not_to have_received(:update)
      end
    end
  end
end
