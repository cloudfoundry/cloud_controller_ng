require 'spec_helper'
require 'cloud_controller/deployment_updater/actions/scale'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Actions::Scale do
    subject(:scale_action) { DeploymentUpdater::Actions::Scale.new(deployment, logger) }
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
    let(:current_deploying_instances) { 0 }

    let(:state) { DeploymentModel::DEPLOYING_STATE }

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

    it 'scales the old web process down by one after the first iteration' do
      expect(original_web_process_instance_count).to be > current_deploying_instances
      expect do
        subject.call
      end.to change {
        web_process.reload.instances
      }.by(-1)
    end

    it 'scales up the new web process by one' do
      expect do
        subject.call
      end.to change {
        deploying_web_process.reload.instances
      }.by(1)
    end

    context 'when the max_in_flight is set to 2' do
      let(:deployment) do
        DeploymentModel.make(
          app: web_process.app,
          deploying_web_process: deploying_web_process,
          state: 'DEPLOYING',
          original_web_process_instance_count: original_web_process_instance_count,
          max_in_flight: 2
        )
      end

      it 'scales up the new web process by two' do
        expect do
          subject.call
        end.to change {
          deploying_web_process.reload.instances
        }.by(2)
      end

      it 'scales the old web process down by two after the first iteration' do
        expect do
          subject.call
        end.to change {
          web_process.reload.instances
        }.by(-2)
      end
    end

    context 'when max_in_flight is larger than the number of remaining desired instances' do
      let(:current_deploying_instances) { 5 }
      let(:deployment) do
        DeploymentModel.make(
          app: web_process.app,
          deploying_web_process: deploying_web_process,
          state: 'DEPLOYING',
          original_web_process_instance_count: 6,
          max_in_flight: 5
        )
      end

      it 'scales up the new web process by the maximum number' do
        expect do
          subject.call
        end.to change {
          deploying_web_process.reload.instances
        }.by(1)
      end

      it 'scales the old web process down to 0' do
        expect do
          subject.call
        end.to change {
          web_process.reload.instances
        }.to(0)
      end
    end

    context 'when the max_in_flight is more than the total number of process instances' do
      let(:deployment) do
        DeploymentModel.make(
          app: web_process.app,
          deploying_web_process: deploying_web_process,
          state: 'DEPLOYING',
          original_web_process_instance_count: original_web_process_instance_count,
          max_in_flight: 100
        )
      end

      it 'scales up the new web process by the maximum number' do
        expect do
          subject.call
        end.to change {
          deploying_web_process.reload.instances
        }.by(original_web_process_instance_count)
      end

      it 'scales the old web process down to 0' do
        expect do
          subject.call
        end.to change {
          web_process.reload.instances
        }.to(0)
      end
    end

    context 'when the deployment process has reached original_web_process_instance_count' do
      let(:droplet) do
        DropletModel.make(
          process_types: {
            'clock' => 'droplet_clock_command',
            'worker' => 'droplet_worker_command'
          }
        )
      end

      let(:current_deploying_instances) { original_web_process_instance_count }

      let!(:interim_deploying_web_process) do
        ProcessModel.make(
          app: web_process.app,
          created_at: an_hour_ago,
          type: ProcessTypes::WEB,
          instances: 1,
          guid: 'guid-interim'
        )
      end

      before do
        allow(ProcessRestart).to receive(:restart)
        RevisionProcessCommandModel.where(
          process_type: 'worker',
          revision_guid: revision.guid
        ).update(process_command: 'revision-non-web-1-command')
      end

      it 'finalizes the deployment' do
        subject.call
        deployment.reload
        expect(deployment.state).to eq(DeploymentModel::DEPLOYED_STATE)
        expect(deployment.status_value).to eq(DeploymentModel::FINALIZED_STATUS_VALUE)
        expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYED_STATUS_REASON)

        after_web_process = deployment.app.web_processes.first
        expect(after_web_process.guid).to eq(deploying_web_process.guid)
        expect(after_web_process.instances).to eq(6)
      end
    end

    context 'when the (oldest) web process will be at zero instances and is type web' do
      let(:current_web_instances) { 1 }
      let(:current_deploying_instances) { 3 }

      it 'does not destroy the web process, but scales it to 0' do
        subject.call
        expect(ProcessModel.find(guid: web_process.guid).instances).to eq 0
      end

      it 'does not destroy any route mappings' do
        expect do
          subject.call
        end.not_to(change(RouteMappingModel, :count))
      end

      context 'when the max_in_flight is set to 10' do
        let(:deployment) do
          DeploymentModel.make(
            app: web_process.app,
            deploying_web_process: deploying_web_process,
            state: 'DEPLOYING',
            original_web_process_instance_count: original_web_process_instance_count,
            max_in_flight: 10
          )
        end

        it 'does not destroy the web process, but scales it to 0' do
          subject.call
          expect(ProcessModel.find(guid: web_process.guid).instances).to eq 0
        end
      end
    end

    context 'when the oldest web process will be at zero instances' do
      let(:current_deploying_instances) { 3 }
      let!(:web_process) do
        ProcessModel.make(
          guid: 'web_process',
          instances: 0,
          app: app,
          created_at: a_day_ago - 11,
          type: ProcessTypes::WEB
        )
      end
      let!(:oldest_web_process_with_instances) do
        ProcessModel.make(
          guid: 'oldest_web_process_with_instances',
          instances: 1,
          app: app,
          created_at: a_day_ago - 10,
          type: ProcessTypes::WEB
        )
      end

      it 'destroys the oldest web process and ignores the original web process' do
        expect do
          subject.call
        end.not_to(change { ProcessModel.find(guid: web_process.guid) })
        expect(ProcessModel.find(guid: oldest_web_process_with_instances.guid)).to be_nil
      end
    end

    context 'when one of the deploying_web_process instances is starting' do
      let(:current_deploying_instances) { 3 }
      let(:all_instances_results) do
        {
          0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
          1 => { state: 'STARTING', uptime: 50, since: 2, routable: true },
          2 => { state: 'STARTING', uptime: 50, since: 2, routable: true }
        }
      end

      it 'does not scales the process' do
        expect do
          subject.call
        end.not_to(change do
          web_process.reload.instances
        end)

        expect do
          subject.call
        end.not_to(change do
          deploying_web_process.reload.instances
        end)
      end
    end

    context 'when one of the deploying_web_process instances is not routable' do
      let(:current_deploying_instances) { 3 }
      let(:all_instances_results) do
        {
          0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
          1 => { state: 'RUNNING', uptime: 50, since: 2, routable: false },
          2 => { state: 'RUNNING', uptime: 50, since: 2, routable: false }
        }
      end

      it 'does not scales the process' do
        expect do
          subject.call
        end.not_to(change do
          web_process.reload.instances
        end)

        expect do
          subject.call
        end.not_to(change do
          deploying_web_process.reload.instances
        end)
      end
    end

    context 'when one of the deploying_web_process instances is failing' do
      let(:current_deploying_instances) { 3 }
      let(:all_instances_results) do
        {
          0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
          1 => { state: 'FAILING', uptime: 50, since: 2, routable: true },
          2 => { state: 'FAILING', uptime: 50, since: 2, routable: true }
        }
      end

      it 'does not scale the process' do
        expect do
          subject.call
        end.not_to(change do
          web_process.reload.instances
        end)

        expect do
          subject.call
        end.not_to(change do
          deploying_web_process.reload.instances
        end)
      end
    end

    context 'when the deployment is deploying' do
      let!(:previous_last_healthy_at) { deployment.last_healthy_at || 0 }

      before do
        TestConfig.override(healthcheck_timeout: 60)
      end

      context 'when all its instances are running' do
        it 'updates last_healthy_at' do
          Timecop.travel(deployment.last_healthy_at + 10.seconds) do
            subject.call
            expect(deployment.reload.last_healthy_at).to be > previous_last_healthy_at
            expect(deployment.state).to eq(DeploymentModel::DEPLOYING_STATE)
            expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
            expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYING_STATUS_REASON)
          end
        end
      end

      context 'when some instances are crashing' do
        let(:all_instances_results) do
          {
            0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
            1 => { state: 'FAILING', uptime: 50, since: 2, routable: true },
            2 => { state: 'FAILING', uptime: 50, since: 2, routable: true }
          }
        end

        it 'changes nothing' do
          subject.call
          expect(deployment.reload.last_healthy_at).to eq previous_last_healthy_at
          expect(deployment.state).to eq(DeploymentModel::DEPLOYING_STATE)
          expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
          expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYING_STATUS_REASON)
        end
      end
    end

    context 'setting deployment last_healthy_at' do
      it 'updates the deployments last_healthy_at when scaling' do
        Timecop.travel(Time.now + 1.minute) do
          expect do
            subject.call
          end.to(change { deployment.reload.last_healthy_at })
        end
      end

      context 'when instances are failing' do
        let(:all_instances_results) do
          {
            0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
            1 => { state: 'FAILING', uptime: 50, since: 2, routable: true },
            2 => { state: 'FAILING', uptime: 50, since: 2, routable: true }
          }
        end

        it 'does not update the deployments last_healthy_at' do
          Timecop.travel(Time.now + 1.minute) do
            expect do
              subject.call
            end.not_to(change { deployment.reload.last_healthy_at })
          end
        end
      end
    end

    context 'when Diego is unavailable while checking instance status' do
      let(:current_deploying_instances) { 3 }

      before do
        allow(instances_reporters).to receive(:all_instances_for_app).and_raise(CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', 'omg it broke'))
      end

      it 'does not scale the process' do
        expect do
          subject.call
        end.not_to(change do
          web_process.reload.instances
        end)

        expect do
          subject.call
        end.not_to(change do
          deploying_web_process.reload.instances
        end)
      end
    end

    describe 'during an upgrade with leftover legacy webish processes' do
      let!(:deploying_web_process) do
        ProcessModel.make(
          app: web_process.app,
          type: 'web-deployment-guid-legacy',
          instances: current_deploying_instances,
          guid: 'guid-legacy',
          revision: revision
        )
      end

      it 'scales up the coerced web process by one' do
        expect do
          subject.call
        end.to change {
          deploying_web_process.reload.instances
        }.by(1)
      end

      context 'when the max_in_flight is set to 10' do
        let(:deployment) do
          DeploymentModel.make(
            app: web_process.app,
            deploying_web_process: deploying_web_process,
            state: 'DEPLOYING',
            original_web_process_instance_count: original_web_process_instance_count,
            max_in_flight: 10
          )
        end

        it 'scales up the coerced web process by the maximum original web process count' do
          expect do
            subject.call
          end.to change {
            deploying_web_process.reload.instances
          }.by(original_web_process_instance_count)
        end
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

    context 'deployment got superseded' do
      before do
        deployment.update(state: 'DEPLOYED', status_reason: 'SUPERSEDED')

        allow(deployment).to receive(:update).and_call_original
      end

      it 'skips execution' do
        subject.call
        expect(deployment).not_to have_received(:update)
      end
    end
  end
end
