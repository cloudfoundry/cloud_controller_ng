require 'spec_helper'
require 'cloud_controller/deployment_updater/actions/cancel'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Actions::Cancel do
    subject(:cancel_action) { DeploymentUpdater::Actions::Cancel.new(deployment, logger) }
    let(:a_day_ago) { Time.now - 1.day }
    let(:an_hour_ago) { Time.now - 1.hour }
    let(:organization) { Organization.make }
    let(:space) { Space.make(organization: organization, space_quota_definition: quota) }
    let(:app) { AppModel.make(droplet: droplet, revisions_enabled: true, space: space) }
    let(:droplet) { DropletModel.make }
    let(:memory) { 1024 }
    let(:memory_limit) { memory * 1000 }
    let(:quota) { SpaceQuotaDefinition.make(organization:, memory_limit:) }
    let!(:web_process) do
      ProcessModel.make(
        instances: current_web_instances,
        created_at: a_day_ago,
        guid: 'guid-original',
        app: app,
        memory: memory,
        state: ProcessModel::STARTED
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
        memory: memory,
        state: ProcessModel::STARTED
      )
    end
    let(:revision) { RevisionModel.make(app: app, droplet: droplet, version: 300) }
    let!(:deploying_route_mapping) { RouteMappingModel.make(app: web_process.app, process_type: deploying_web_process.type) }
    let(:original_web_process_instance_count) { 6 }
    let(:current_web_instances) { 2 }

    let(:state) { DeploymentModel::CANCELING_STATE }
    let(:current_deploying_instances) { 0 }

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
      allow_any_instance_of(VCAP::CloudController::Diego::Runner).to receive(:stop)
    end

    it 'deletes the deploying process' do
      subject.call
      expect(ProcessModel.find(guid: deploying_web_process.guid)).to be_nil
    end

    it 'rolls back to the correct number of instances' do
      subject.call
      expect(web_process.reload.instances).to eq(original_web_process_instance_count)
      expect(ProcessModel.find(guid: deploying_web_process.guid)).to be_nil
    end

    it 'sets the deployment to CANCELED' do
      subject.call
      expect(deployment.state).to eq(DeploymentModel::CANCELED_STATE)
      expect(deployment.status_value).to eq(DeploymentModel::FINALIZED_STATUS_VALUE)
      expect(deployment.status_reason).to eq(DeploymentModel::CANCELED_STATUS_REASON)
    end

    context 'when there are interim deployments' do
      let!(:interim_deploying_web_process) do
        ProcessModel.make(
          app: app,
          created_at: an_hour_ago,
          type: ProcessTypes::WEB,
          instances: 1,
          guid: 'guid-interim'
        )
      end
      let!(:interim_deployed_superseded_deployment) do
        DeploymentModel.make(
          deploying_web_process: interim_deploying_web_process,
          state: 'DEPLOYED',
          status_reason: 'SUPERSEDED'
        )
      end
      let!(:interim_route_mapping) do
        RouteMappingModel.make(
          app: web_process.app,
          process_type: interim_deploying_web_process.type
        )
      end

      it 'scales up the most recent interim web process' do
        subject.call
        expect(interim_deploying_web_process.reload.instances).to eq(original_web_process_instance_count)
        expect(app.reload.web_processes.first.guid).to eq(interim_deploying_web_process.guid)
      end

      it 'sets the most recent interim web process as the only web process' do
        subject.call
        expect(app.reload.processes.map(&:guid)).to eq([interim_deploying_web_process.guid])
      end

      context 'when there is an interim deployment that has been SUPERSEDED (CANCELED)' do
        let!(:interim_canceling_web_process) do
          ProcessModel.make(
            app: app,
            created_at: an_hour_ago + 1,
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

        it 'sets the most recent interim web process belonging to a SUPERSEDED (DEPLOYED) deployment as the only web process' do
          subject.call
          expect(app.reload.processes.map(&:guid)).to eq([interim_deploying_web_process.guid])
        end
      end

      context 'when there is an interim deployment that has no running web process instance' do
        let(:no_running_instance) do
          {
            0 => { state: 'STARTING' },
            1 => { state: 'CRASHED' },
            2 => { state: 'DOWN' }
          }
        end
        let!(:interim_deploying_web_process_no_running_instance) do
          ProcessModel.make(
            app: app,
            created_at: an_hour_ago + 1,
            type: ProcessTypes::WEB,
            instances: 1,
            guid: 'guid-no-running-instance'
          )
        end
        let!(:interim_deployed_superseded_deployment_no_running_instance) do
          DeploymentModel.make(
            deploying_web_process: interim_deploying_web_process_no_running_instance,
            state: 'DEPLOYED',
            status_reason: 'SUPERSEDED'
          )
        end

        before do
          allow(instances_reporters).to receive(:all_instances_for_app).and_return(no_running_instance, all_instances_results)
        end

        it 'sets the most recent interim web process having at least one running instance as the only web process' do
          subject.call
          expect(app.reload.processes.map(&:guid)).to eq([interim_deploying_web_process.guid])
        end
      end
    end

    context 'deployment got superseded' do
      before do
        deployment.update(state: 'CANCELED', status_reason: 'SUPERSEDED')

        allow(deployment).to receive(:update).and_call_original
      end

      it 'skips execution' do
        subject.call
        expect(deployment).not_to have_received(:update)
      end
    end

    context 'when the app is at a quota limit' do
      let(:current_web_instances) { 1 }
      let(:current_deploying_instances) { original_web_process_instance_count }
      let(:memory_limit) { memory * (current_deploying_instances + current_web_instances) }

      it 'can still be cancelled succesfully' do
        expect { subject.call }.not_to raise_error
        expect(ProcessModel.find(guid: deploying_web_process.guid)).to be_nil
      end
    end
  end
end
