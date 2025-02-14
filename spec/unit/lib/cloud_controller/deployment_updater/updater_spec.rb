require 'spec_helper'
require 'cloud_controller/deployment_updater/updater'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Updater do
    subject(:updater) { DeploymentUpdater::Updater.new(deployment, logger) }
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

    let(:all_instances_results) do
      {
        0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
        1 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
        2 => { state: 'RUNNING', uptime: 50, since: 2, routable: true }
      }
    end
    let(:logger) { instance_double(Steno::Logger, info: nil, error: nil) }

    let(:diego_reporter) { Diego::InstancesReporter.new(nil) }

    before do
      allow_any_instance_of(VCAP::CloudController::InstancesReporters).to receive(:diego_reporter).and_return(diego_reporter)
      allow(diego_reporter).to receive(:all_instances_for_app).and_return(all_instances_results)
    end

    describe '#scale' do
      context 'when the deployment process has reached original_web_process_instance_count' do
        let(:droplet) do
          DropletModel.make(
            process_types: {
              'clock' => 'droplet_clock_command',
              'worker' => 'droplet_worker_command'
            }
          )
        end

        let(:all_instances_results) do
          {
            0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
            1 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
            2 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
            3 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
            4 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
            5 => { state: 'RUNNING', uptime: 50, since: 2, routable: true }
          }
        end

        let(:current_deploying_instances) { 6 }

        before do
          allow(ProcessRestart).to receive(:restart)
          RevisionProcessCommandModel.where(
            process_type: 'worker',
            revision_guid: revision.guid
          ).update(process_command: 'revision-non-web-1-command')
        end

        it 'finalizes the deployment' do
          subject.scale
          deployment.reload
          expect(deployment.state).to eq(DeploymentModel::DEPLOYED_STATE)
          expect(deployment.status_value).to eq(DeploymentModel::FINALIZED_STATUS_VALUE)
          expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYED_STATUS_REASON)

          after_web_process = deployment.app.web_processes.first
          expect(after_web_process.guid).to eq(deploying_web_process.guid)
          expect(after_web_process.instances).to eq(6)
        end

        context 'but one instance is failing' do
          let(:all_instances_results) do
            {
              0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
              1 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
              2 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
              3 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
              4 => { state: 'RUNNING', uptime: 50, since: 2, routable: true },
              5 => { state: 'FAILING', uptime: 50, since: 2, routable: false }
            }
          end

          it 'doesn\'t finalize the deployment' do
            skip 'Seems like we shouldn\'t finalize if there is a failing instance, but that is the current behavior'
            subject.scale
            deployment.reload
            expect(deployment.state).to eq(DeploymentModel::DEPLOYING_STATE)
          end
        end
      end

      context 'when an error occurs while scaling a deployment' do
        let(:failing_process) { ProcessModel.make(app: web_process.app, type: 'failing', instances: 5) }
        let(:deployment) { DeploymentModel.make(app: web_process.app, deploying_web_process: failing_process, state: 'DEPLOYING') }

        before do
          allow(deployment).to receive(:app).and_raise(StandardError.new('Something real bad happened'))
        end

        it 'logs the error' do
          expect do
            subject.scale
          end.not_to(change do
            failing_process.reload.instances
          end)

          expect(logger).to have_received(:error).with(
            'error-scaling-deployment',
            deployment_guid: deployment.guid,
            error: 'StandardError',
            error_message: 'Something real bad happened',
            backtrace: anything
          )
        end

        it 'does not throw an error (so that other deployments can still proceed)' do
          expect do
            subject.scale
          end.not_to raise_error
        end
      end
    end

    describe '#canary' do
      let(:state) { DeploymentModel::PREPAUSED_STATE }
      let(:current_deploying_instances) { 1 }

      context 'when the canary instance starts succesfully' do
        let(:all_instances_results) do
          {
            0 => { state: 'RUNNING', uptime: 50, since: 2, routable: true }
          }
        end

        it 'logs the canary is paused' do
          subject.canary
          expect(logger).to have_received(:info).with(
            "paused-canary-deployment-for-#{deployment.guid}"
          )
        end

        it 'logs the canary run' do
          subject.canary
          expect(logger).to have_received(:info).with(
            "ran-canarying-deployment-for-#{deployment.guid}"
          )
        end
      end

      context 'when an error occurs while canarying a deployment' do
        before do
          allow(deployment).to receive(:lock!).and_raise(StandardError.new('Something real bad happened'))
        end

        it 'logs the error' do
          subject.canary

          expect(logger).to have_received(:error).with(
            'error-canarying-deployment',
            deployment_guid: deployment.guid,
            error: 'StandardError',
            error_message: 'Something real bad happened',
            backtrace: anything
          )
        end

        it 'does not throw an error (so that other deployments can still proceed)' do
          expect do
            subject.canary
          end.not_to raise_error
        end
      end
    end

    describe '#cancel' do
      before do
        deployment.update(state: 'CANCELING')
        allow_any_instance_of(VCAP::CloudController::Diego::Runner).to receive(:stop)
      end

      context 'when an error occurs while canceling a deployment' do
        before do
          allow(deployment).to receive(:lock!).and_raise(StandardError.new('Something real bad happened'))
        end

        it 'logs the error' do
          subject.cancel

          expect(logger).to have_received(:error).with(
            'error-canceling-deployment',
            deployment_guid: deployment.guid,
            error: 'StandardError',
            error_message: 'Something real bad happened',
            backtrace: anything
          )
        end

        it 'does not throw an error (so that other deployments can still proceed)' do
          expect do
            subject.cancel
          end.not_to raise_error
        end
      end
    end
  end
end
