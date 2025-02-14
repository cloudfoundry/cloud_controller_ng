require 'spec_helper'
require 'cloud_controller/deployment_updater/actions/scale'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Actions::Scale do
    subject(:scale_action) { DeploymentUpdater::Actions::Scale.new(deployment, logger, target_total_instance_count) }
    let(:target_total_instance_count) { 6 }

    let(:app) { AppModel.make(droplet: droplet, revisions_enabled: true) }
    let(:droplet) { DropletModel.make }
    let!(:web_process) do
      ProcessModel.make(
        instances: current_web_instances,
        created_at: 1.day.ago,
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
    let(:current_web_instances) { 6 }
    let(:current_deploying_instances) { 0 }

    let(:state) { DeploymentModel::DEPLOYING_STATE }

    let(:deployment) do
      DeploymentModel.make(
        app: web_process.app,
        deploying_web_process: deploying_web_process,
        state: state,
        max_in_flight: max_in_flight
      )
    end

    let(:max_in_flight) { 1 }

    let(:all_instances_results) do
      instances = {}
      current_deploying_instances.times do |i|
        instances[i] = { state: 'RUNNING', uptime: 50, since: 2, routable: true }
      end
      instances
    end

    let(:logger) { instance_double(Steno::Logger, info: nil, error: nil) }
    let(:diego_reporter) { Diego::InstancesReporter.new(nil) }

    before do
      allow_any_instance_of(VCAP::CloudController::InstancesReporters).to receive(:diego_reporter).and_return(diego_reporter)
      allow(diego_reporter).to receive(:all_instances_for_app).and_return(all_instances_results)
    end

    it 'locks the deployment' do
      allow(deployment).to receive(:lock!).and_call_original
      subject.call
      expect(deployment).to have_received(:lock!)
    end

    context 'after a new instance has been brought up' do
      let(:current_deploying_instances) { 1 }

      it 'scales the old web process down by one' do
        expect(target_total_instance_count).to be > current_deploying_instances
        expect do
          subject.call
        end.to change {
          web_process.reload.instances
        }.by(-1)
      end
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

      it 'doesnt scale down the old web process (there are no new routable instances yet)' do
        expect do
          subject.call
        end.not_to(change do
          web_process.reload.instances
        end)
      end
    end

    context 'when max_in_flight is larger than the number of remaining desired instances' do
      let(:current_deploying_instances) { 5 }
      let(:deployment) do
        DeploymentModel.make(
          app: web_process.app,
          deploying_web_process: deploying_web_process,
          state: 'DEPLOYING',
          max_in_flight: 5
        )
      end

      let(:current_web_instances) { 1 }

      it 'scales up the new web process by the maximum number' do
        expect do
          subject.call
        end.to change {
          deploying_web_process.reload.instances
        }.by(1)
      end

      it 'doesnt scale down the old web process (there are no new routable instances yet)' do
        expect do
          subject.call
        end.not_to(change do
          web_process.reload.instances
        end)
      end
    end

    context 'when the max_in_flight is more than the total number of process instances' do
      let(:deployment) do
        DeploymentModel.make(
          app: web_process.app,
          deploying_web_process: deploying_web_process,
          state: 'DEPLOYING',
          max_in_flight: 100
        )
      end

      it 'scales up the new web process by the maximum number' do
        expect do
          subject.call
        end.to change {
          deploying_web_process.reload.instances
        }.by(target_total_instance_count)
      end

      it 'doesnt scale down the old web process (there is no new routable instance yet)' do
        expect do
          subject.call
        end.not_to(change do
          web_process.reload.instances
        end)
      end
    end

    context 'when the deployment process has reached interim_desired_instance_count' do
      let(:interim_desired_instance_count) { 3 }
      let(:target_total_instance_count) { 6 }

      let(:droplet) do
        DropletModel.make(
          process_types: {
            'clock' => 'droplet_clock_command',
            'worker' => 'droplet_worker_command'
          }
        )
      end

      subject(:scale_action) { DeploymentUpdater::Actions::Scale.new(deployment, logger, target_total_instance_count, interim_desired_instance_count) }

      let(:current_deploying_instances) { interim_desired_instance_count }

      let!(:interim_deploying_web_process) do
        ProcessModel.make(
          app: web_process.app,
          created_at: 1.hour.ago,
          type: ProcessTypes::WEB,
          instances: 1,
          guid: 'guid-interim'
        )
      end

      it 'returns true and leaves the deployment in a deploying state' do
        expect(subject.call).to be true
        deployment.reload
        expect(deployment.state).to eq(DeploymentModel::DEPLOYING_STATE)

        earliest_web_process = deployment.app.web_processes.first
        expect(earliest_web_process.guid).to eq(web_process.guid)
        expect(earliest_web_process.instances).to eq(2)
        expect(interim_deploying_web_process.instances).to eq(1)

        expect(deploying_web_process.instances).to eq(3)
      end
    end

    context 'when the (oldest) web process will be at zero instances and is type web' do
      let(:current_web_instances) { 1 }
      let(:current_deploying_instances) { 3 }
      let(:target_total_instance_count) { 6 }

      let!(:interim_deploying_web_process) do
        ProcessModel.make(
          app: web_process.app,
          created_at: 1.hour.ago,
          type: ProcessTypes::WEB,
          instances: 3,
          guid: 'guid-interim'
        )
      end

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
          created_at: 1.day.ago - 11,
          type: ProcessTypes::WEB
        )
      end
      let!(:oldest_web_process_with_instances) do
        ProcessModel.make(
          guid: 'oldest_web_process_with_instances',
          instances: 1,
          app: app,
          created_at: 1.day.ago - 10,
          type: ProcessTypes::WEB
        )
      end
      let!(:other_web_process_with_instances) do
        ProcessModel.make(
          instances: 10,
          app: app,
          created_at: 1.hour.ago,
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

    context 'when there are more instances in interim processes than there should be' do
      let(:current_deploying_instances) { 10 }
      let(:target_total_instance_count) { 20 }
      let(:max_in_flight) { 4 }

      let!(:web_process) do
        ProcessModel.make(
          guid: 'web_process',
          instances: 10,
          app: app,
          created_at: 1.day.ago - 11,
          type: ProcessTypes::WEB
        )
      end
      let!(:oldest_web_process_with_instances) do
        ProcessModel.make(
          guid: 'oldest_web_process_with_instances',
          instances: 10,
          app: app,
          created_at: 1.day.ago - 10,
          type: ProcessTypes::WEB
        )
      end
      let!(:other_web_process_with_instances) do
        ProcessModel.make(
          instances: 10,
          app: app,
          created_at: 1.day.ago - 9,
          type: ProcessTypes::WEB
        )
      end

      it 'scales down interim proceses so all instances equal original instance count + max in flight' do
        non_deploying_instance_count = app.web_processes.reject { |p| p.guid == deploying_web_process.guid }.map(&:instances).sum
        expect(non_deploying_instance_count).to eq 30
        expect(deploying_web_process.instances).to eq 10

        subject.call

        non_deploying_instance_count = app.reload.web_processes.reject { |p| p.guid == deploying_web_process.guid }.map(&:instances).sum
        expect(non_deploying_instance_count).to eq 10
        expect(deploying_web_process.reload.instances).to eq 14
      end

      it 'destroys interim processes that have been scaled down' do
        subject.call
        expect(ProcessModel.find(guid: web_process.guid)).to be_present
        expect(ProcessModel.find(guid: oldest_web_process_with_instances.guid)).to be_nil
        expect(ProcessModel.find(guid: other_web_process_with_instances.guid)).to be_present
      end

      context 'when all in-flight instances are not up' do
        let(:all_instances_results) do
          {
            0 => { state: 'RUNNING',  uptime: 50, since: 2, routable: true },
            1 => { state: 'RUNNING',  uptime: 50, since: 2, routable: true },
            2 => { state: 'RUNNING',  uptime: 50, since: 2, routable: true },
            3 => { state: 'RUNNING',  uptime: 50, since: 2, routable: true },
            4 => { state: 'RUNNING',  uptime: 50, since: 2, routable: true },
            5 => { state: 'RUNNING',  uptime: 50, since: 2, routable: true },
            6 => { state: 'STARTING', uptime: 50, since: 2, routable: true },
            7 => { state: 'STARTING', uptime: 50, since: 2, routable: true },
            8 => { state: 'DOWN',     uptime: 0,  since: 2, routable: false },
            9 => { state: 'FAILING',  uptime: 50, since: 2, routable: false }
          }
        end

        it 'scales down interim proceses so all instances equal original instance count + max in flight' do
          non_deploying_instance_count = app.web_processes.reject { |p| p.guid == deploying_web_process.guid }.map(&:instances).sum
          expect(non_deploying_instance_count).to eq 30
          expect(deploying_web_process.instances).to eq 10

          subject.call

          non_deploying_instance_count = app.reload.web_processes.reject { |p| p.guid == deploying_web_process.guid }.map(&:instances).sum
          expect(non_deploying_instance_count).to eq 14
          expect(deploying_web_process.reload.instances).to eq 10
        end
      end
    end

    context 'when there are fewer instances in interim processes than there should be' do
      let(:current_deploying_instances) { 10 }
      let(:target_total_instance_count) { 20 }
      let(:max_in_flight) { 4 }

      let!(:web_process) do
        ProcessModel.make(
          guid: 'web_process',
          instances: 1,
          app: app,
          created_at: 1.day.ago - 11,
          type: ProcessTypes::WEB
        )
      end
      let!(:oldest_web_process_with_instances) do
        ProcessModel.make(
          guid: 'oldest_web_process_with_instances',
          instances: 1,
          app: app,
          created_at: 1.day.ago - 10,
          type: ProcessTypes::WEB
        )
      end
      let!(:other_web_process_with_instances) do
        ProcessModel.make(
          instances: 1,
          app: app,
          created_at: 1.day.ago - 10,
          type: ProcessTypes::WEB
        )
      end

      it 'doesnt try to scale up or down the iterim processes' do
        non_deploying_instance_count = app.web_processes.reject { |p| p.guid == deploying_web_process.guid }.map(&:instances).sum
        expect(non_deploying_instance_count).to eq 3
        expect(deploying_web_process.reload.instances).to eq 10

        subject.call

        non_deploying_instance_count = app.web_processes.reject { |p| p.guid == deploying_web_process.guid }.map(&:instances).sum
        expect(non_deploying_instance_count).to eq 3
        expect(deploying_web_process.reload.instances).to eq 14
      end
    end

    context 'when some instances are missing' do
      let(:current_web_instances) { 10 }
      let(:target_total_instance_count) { 10 }

      let(:current_deploying_instances) { 9 }
      let(:max_in_flight) { 5 }

      let(:all_instances_results) do
        {
          0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true }
        }
      end

      it 'doesn\'t upscale' do
        expect(web_process.instances).to eq 10
        expect(deploying_web_process.instances).to eq 9

        subject.call

        expect(web_process.reload.instances).to eq 9
        expect(deploying_web_process.reload.instances).to eq 9
      end
    end

    context 'when some, but not all, instances have finished' do
      let(:current_web_instances) { 10 }
      let(:target_total_instance_count) { 10 }

      let(:current_deploying_instances) { 5 }
      let(:max_in_flight) { 5 }

      let(:all_instances_results) do
        {
          0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
          1 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
          2 => { state: 'STARTING', uptime: 50, since: 2, routable: true },
          3 => { state: 'RUNNING', uptime: 50, since: 2, routable: false },
          4 => { state: 'STARTING', uptime: 50, since: 2, routable: false }
        }
      end

      it 'scales more instances to match max_in_flight' do
        expect(web_process.instances).to eq 10
        expect(deploying_web_process.instances).to eq 5

        subject.call

        expect(web_process.reload.instances).to eq 8
        expect(deploying_web_process.reload.instances).to eq 7
      end
    end

    context 'when greater than or equal to max_in_flight of the deploying_web_process instances is starting' do
      let(:current_deploying_instances) { 3 }
      let(:max_in_flight) { 2 }
      let(:all_instances_results) do
        {
          0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
          1 => { state: 'STARTING', uptime: 50, since: 2, routable: true },
          2 => { state: 'STARTING', uptime: 50, since: 2, routable: true }
        }
      end

      it 'downscales the original process' do
        expect do
          subject.call
        end.to(change do
          web_process.reload.instances
        end.from(6).to(5))
      end

      it 'does not scale the deploying web process' do
        expect do
          subject.call
        end.not_to(change do
          deploying_web_process.reload.instances
        end)
      end
    end

    context 'when greater than or equal to max_in_flight of the deploying_web_process instances is not routable' do
      let(:current_deploying_instances) { 3 }
      let(:max_in_flight) { 2 }
      let(:all_instances_results) do
        {
          0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
          1 => { state: 'RUNNING', uptime: 50, since: 2, routable: false },
          2 => { state: 'RUNNING', uptime: 50, since: 2, routable: false }
        }
      end

      it 'downscales the original process' do
        expect do
          subject.call
        end.to(change do
          web_process.reload.instances
        end.from(6).to(5))
      end

      it 'does not scale the deploying web process' do
        expect do
          subject.call
        end.not_to(change do
          deploying_web_process.reload.instances
        end)
      end
    end

    context 'when greater than or equal to max_in_flight of the deploying_web_process instances is failing' do
      let(:current_deploying_instances) { 3 }
      let(:max_in_flight) { 2 }
      let(:all_instances_results) do
        {
          0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
          1 => { state: 'FAILING', uptime: 50, since: 2, routable: true },
          2 => { state: 'CRASHED', uptime: 50, since: 2, routable: true }
        }
      end

      it 'downscales the original process' do
        expect do
          subject.call
        end.to(change do
          web_process.reload.instances
        end.from(6).to(5))
      end

      it 'does not scale the deploying web process' do
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
        allow(diego_reporter).to receive(:all_instances_for_app).and_raise(CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', 'omg it broke'))
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
            max_in_flight: 10
          )
        end

        it 'scales up the coerced web process by the maximum original web process count' do
          expect do
            subject.call
          end.to change {
            deploying_web_process.reload.instances
          }.by(target_total_instance_count)
        end
      end
    end

    context 'when there is an interim deployment that has been SUPERSEDED (CANCELED)' do
      let!(:interim_canceling_web_process) do
        ProcessModel.make(
          app: app,
          created_at: 1.hour.ago,
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

    describe 'interim_desired_instance_count' do
      let(:deployment) do
        DeploymentModel.make(
          app: web_process.app,
          deploying_web_process: deploying_web_process,
          state: 'DEPLOYING',
          max_in_flight: 100
        )
      end

      context 'when not passed in' do
        subject(:scale_action) { DeploymentUpdater::Actions::Scale.new(deployment, logger, target_total_instance_count) }
        let(:target_total_instance_count) { 6 }

        it 'scales up the new web process to the target_total_instance_count' do
          expect do
            subject.call
          end.to change {
            deploying_web_process.reload.instances
          }.by(target_total_instance_count)
        end

        it 'doesnt scale down the old web process (there is no new routable instance yet)' do
          expect do
            subject.call
          end.not_to(change do
            web_process.reload.instances
          end)
        end

        context 'when there are routable instances' do
          let(:current_deploying_instances) { 6 }

          it 'does scale down the old web process' do
            expect do
              subject.call
            end.to(change do
              web_process.reload.instances
            end.from(6).to(0))
          end
        end
      end

      context 'when passed in' do
        let(:interim_desired_instance_count) { 3 }
        let(:target_total_instance_count) { 6 }

        subject(:scale_action) { DeploymentUpdater::Actions::Scale.new(deployment, logger, target_total_instance_count, interim_desired_instance_count) }

        it 'scales up the new web process to the interim_desired_instance_count' do
          expect do
            subject.call
          end.to change {
            deploying_web_process.reload.instances
          }.by(interim_desired_instance_count)
        end

        it 'doesnt scale down the old web process (there is no new routable instance yet)' do
          expect do
            subject.call
          end.not_to(change do
            web_process.reload.instances
          end)
        end

        context 'when there are routable instances' do
          let(:current_deploying_instances) { 3 }

          it 'does scale down the old web process' do
            expect do
              subject.call
            end.to(change do
              web_process.reload.instances
            end.from(6).to(3))
          end
        end
      end
    end
  end
end
