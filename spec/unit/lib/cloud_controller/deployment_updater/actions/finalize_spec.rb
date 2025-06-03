require 'spec_helper'
require 'cloud_controller/deployment_updater/actions/finalize'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Actions::Finalize do
    subject(:finalize_action) { DeploymentUpdater::Actions::Finalize.new(deployment) }

    let(:app) { AppModel.make(revisions_enabled: true) }
    let(:droplet) { DropletModel.make(app: app, process_types: { 'web' => 'serve', 'worker' => 'work' }) }

    let(:state) { DeploymentModel::DEPLOYING_STATE }

    let!(:old_web_process) do
      ProcessModel.make(
        instances: 3,
        created_at: 3.hours.ago,
        type: ProcessTypes::WEB,
        guid: 'guid-original',
        app: app
      )
    end

    let!(:old_worker_process) do
      ProcessModel.make(
        instances: 3,
        type: 'worker',
        command: 'old_command',
        guid: 'worker-guid-original',
        app: app
      )
    end

    let!(:old_nonweb_process) do
      ProcessModel.make(
        instances: 3,
        type: 'nonweb',
        command: nil,
        guid: 'nonweb-guid-original',
        app: app
      )
    end

    let(:revision) { RevisionModel.make(:no_commands, app: app, droplet: droplet, version: 300) }

    let!(:web_process_command) do
      RevisionProcessCommandModel.make(
        revision: revision,
        process_type: 'web',
        process_command: 'new_web_command'
      )
    end

    let!(:worker_process_command) do
      RevisionProcessCommandModel.make(
        revision: revision,
        process_type: 'worker',
        process_command: 'new_worker_command'
      )
    end

    let!(:deploying_web_process) do
      ProcessModel.make(
        app: app,
        type: ProcessTypes::WEB,
        instances: 3,
        guid: 'guid-final',
        revision: revision,
        state: ProcessModel::STOPPED
      )
    end

    let!(:interim_deploying_web_process) do
      ProcessModel.make(
        app: app,
        created_at: 1.hour.ago,
        type: ProcessTypes::WEB,
        instances: 1,
        guid: 'guid-interim'
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

    let(:diego_instances_reporter) { instance_double(Diego::InstancesReporter) }
    let(:all_instances_results) do
      {
        0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
        1 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
        2 => { state: 'RUNNING', uptime: 50, since: 2, routable: true }
      }
    end
    let(:instances_reporters) { double(:instance_reporters) }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
      allow(instances_reporters).to receive(:all_instances_for_app).and_return(all_instances_results)
      allow(ProcessRestart).to receive(:restart)
    end

    it 'updates the commands of non-web processes from the revision commands' do
      subject.call
      expect(old_worker_process.reload.command).to eq('new_worker_command')
    end

    it 'puts the deployment into its finished DEPLOYED_STATE' do
      subject.call
      deployment.reload
      expect(deployment.state).to eq(DeploymentModel::DEPLOYED_STATE)
      expect(deployment.status_value).to eq(DeploymentModel::FINALIZED_STATUS_VALUE)
      expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYED_STATUS_REASON)
    end

    it 'restarts the non-web processes with the deploying process revision, but not the web process' do
      subject.call

      expect(ProcessRestart).
        to have_received(:restart).
        with(process: old_worker_process, config: TestConfig.config_instance, stop_in_runtime: true, revision: revision)

      expect(ProcessRestart).
        to have_received(:restart).
        with(process: old_nonweb_process, config: TestConfig.config_instance, stop_in_runtime: true, revision: revision)

      expect(ProcessRestart).
        not_to have_received(:restart).
        with(process: old_web_process, config: TestConfig.config_instance, stop_in_runtime: true)

      expect(ProcessRestart).
        not_to have_received(:restart).
        with(process: deploying_web_process, config: TestConfig.config_instance, stop_in_runtime: true)
    end

    it 'cleans up any extra processes from the deployment train' do
      subject.call
      expect(ProcessModel.find(guid: interim_deploying_web_process.guid)).to be_nil
    end

    context 'when revisions are disabled so the deploying web process does not have one' do
      before do
        deploying_web_process.update(revision: nil)
      end

      it 'leaves the non-web process commands alone' do
        subject.call

        expect(old_worker_process.reload.command).to eq('old_command')
        expect(old_nonweb_process.reload.command).to be_nil
      end
    end

    it 'replaces the existing web process with the deploying_web_process' do
      deploying_web_process_guid = deploying_web_process.guid
      expect(ProcessModel.map(&:type)).to match_array(%w[web web web worker nonweb])

      subject.call

      deployment.reload
      deployment.app.reload

      after_web_process = deployment.app.web_processes.first
      expect(after_web_process.guid).to eq(deploying_web_process_guid)
      expect(after_web_process.instances).to eq(3)

      expect(ProcessModel.find(guid: deploying_web_process_guid)).not_to be_nil
      expect(ProcessModel.find(guid: deployment.app.guid)).to be_nil

      expect(ProcessModel.map(&:type)).to match_array(%w[web worker nonweb])
    end
  end
end
