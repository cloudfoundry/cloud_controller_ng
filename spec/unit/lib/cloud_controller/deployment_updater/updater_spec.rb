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
        app: app,
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
        state: ProcessModel::STOPPED,
      )
    end
    let(:revision) { RevisionModel.make(app: app, droplet: droplet, version: 300) }
    let!(:deploying_route_mapping) { RouteMappingModel.make(app: web_process.app, process_type: deploying_web_process.type) }
    let(:space) { web_process.space }
    let(:original_web_process_instance_count) { 6 }
    let(:current_web_instances) { 2 }
    let(:current_deploying_instances) { 0 }

    let(:deployment) do
      DeploymentModel.make(
        app: web_process.app,
        deploying_web_process: deploying_web_process,
        state: 'DEPLOYING',
        original_web_process_instance_count: original_web_process_instance_count
      )
    end

    let(:diego_instances_reporter) { instance_double(Diego::InstancesReporter) }
    let(:all_instances_results) {
      {
        0 => { state: 'RUNNING', uptime: 50, since: 2 },
        1 => { state: 'RUNNING', uptime: 50, since: 2 },
        2 => { state: 'RUNNING', uptime: 50, since: 2 },
      }
    }
    let(:instances_reporters) { double(:instance_reporters) }
    let(:logger) { instance_double(Steno::Logger, info: nil, error: nil) }

    describe '#scale' do
      before do
        allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
        allow(instances_reporters).to receive(:all_instances_for_app).and_return(all_instances_results)
      end

      it 'locks the deployment' do
        allow(deployment).to receive(:lock!).and_call_original
        subject.scale
        expect(deployment).to have_received(:lock!)
      end

      it 'scales the old web process down by one after the first iteration' do
        expect {
          subject.scale
        }.to change {
          web_process.reload.instances
        }.by(-1)
      end

      it 'scales up the new web process by one' do
        expect {
          subject.scale
        }.to change {
          deploying_web_process.reload.instances
        }.by(1)
      end

      context 'when the deployment process has reached original_web_process_instance_count' do
        let(:droplet) do
          DropletModel.make(
            process_types: {
              'clock' => 'droplet_clock_command',
              'worker' => 'droplet_worker_command',
            })
        end

        let(:current_deploying_instances) { original_web_process_instance_count }

        let!(:interim_deploying_web_process) {
          ProcessModel.make(
            app: web_process.app,
            created_at: an_hour_ago,
            type: ProcessTypes::WEB,
            instances: 1,
            guid: 'guid-interim'
          )
        }

        let!(:interim_route_mapping) { RouteMappingModel.make(app: web_process.app, process_type: interim_deploying_web_process.type) }

        let!(:non_web_process1) { ProcessModel.make(app: web_process.app, instances: 2, type: 'worker', command: 'something-else') }

        let!(:non_web_process2) { ProcessModel.make(app: web_process.app, instances: 2, type: 'clock') }

        let!(:route1) { Route.make(space: space, host: 'hostname1') }
        let!(:route_mapping1) { RouteMappingModel.make(app: web_process.app, route: route1, process_type: web_process.type) }
        let!(:route2) { Route.make(space: space, host: 'hostname2') }
        let!(:route_mapping2) { RouteMappingModel.make(app: deploying_web_process.app, route: route2, process_type: deploying_web_process.type) }

        before do
          allow(ProcessRestart).to receive(:restart)
          RevisionProcessCommandModel.where(
            process_type: 'worker',
            revision_guid: revision.guid
          ).update(process_command: 'revision-non-web-1-command')
        end

        it 'replaces the existing web process with the deploying_web_process' do
          deploying_web_process_guid = deploying_web_process.guid
          expect(ProcessModel.map(&:type)).to match_array(['web', 'web', 'web', 'worker', 'clock'])

          subject.scale

          deployment.reload
          deployment.app.reload

          after_web_process = deployment.app.web_processes.first
          expect(after_web_process.guid).to eq(deploying_web_process_guid)
          expect(after_web_process.instances).to eq(original_web_process_instance_count)

          expect(ProcessModel.find(guid: deploying_web_process_guid)).not_to be_nil
          expect(ProcessModel.find(guid: deployment.app.guid)).to be_nil

          expect(ProcessModel.map(&:type)).to match_array(['web', 'worker', 'clock'])
        end

        it 'cleans up any extra processes from the deployment train' do
          subject.scale
          expect(ProcessModel.find(guid: interim_deploying_web_process.guid)).to be_nil
        end

        it 'puts the deployment into its finished DEPLOYED_STATE' do
          subject.scale
          deployment.reload
          expect(deployment.state).to eq(DeploymentModel::DEPLOYED_STATE)
          expect(deployment.status_value).to eq(DeploymentModel::FINALIZED_STATUS_VALUE)
          expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYED_STATUS_REASON)
        end

        it 'restarts the non-web processes with the deploying process revision, but not the web process' do
          subject.scale

          expect(ProcessRestart).
            to have_received(:restart).
            with(process: non_web_process1, config: TestConfig.config_instance, stop_in_runtime: true, revision: revision)

          expect(ProcessRestart).
            to have_received(:restart).
            with(process: non_web_process2, config: TestConfig.config_instance, stop_in_runtime: true, revision: revision)

          expect(ProcessRestart).
            not_to have_received(:restart).
            with(process: web_process, config: TestConfig.config_instance, stop_in_runtime: true)

          expect(ProcessRestart).
            not_to have_received(:restart).
            with(process: deploying_web_process, config: TestConfig.config_instance, stop_in_runtime: true)

          deployment.reload
          expect(deployment.state).to eq(DeploymentModel::DEPLOYED_STATE)
          expect(deployment.status_value).to eq(DeploymentModel::FINALIZED_STATUS_VALUE)
          expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYED_STATUS_REASON)
        end

        it 'sets the commands on the non-web processes to be the commands from the revision of the deploying web process' do
          subject.scale

          expect(non_web_process1.reload.command).to eq('revision-non-web-1-command')
          expect(non_web_process2.reload.command).to be_nil
        end

        context 'when revisions are disabled so the deploying web process does not have one' do
          before do
            deploying_web_process.update(revision: nil)
          end

          it 'it leaves the non-web process commands alone' do
            subject.scale

            expect(logger).not_to have_received(:error)
            expect(non_web_process1.reload.command).to eq('something-else')
            expect(non_web_process2.reload.command).to be_nil
          end
        end
      end

      context 'when the (oldest) web process will be at zero instances and is type web' do
        let(:current_web_instances) { 1 }
        let(:current_deploying_instances) { 3 }

        it 'does not destroy the web process, but scales it to 0' do
          subject.scale
          expect(ProcessModel.find(guid: web_process.guid).instances).to eq 0
        end

        it 'does not destroy any route mappings' do
          expect do
            subject.scale
          end.not_to change {
            RouteMappingModel.count
          }
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
            type: ProcessTypes::WEB,
          )
        end
        let!(:oldest_web_process_with_instances) do
          ProcessModel.make(
            guid: 'oldest_web_process_with_instances',
            instances: 1,
            app: app,
            created_at: a_day_ago - 10,
            type: ProcessTypes::WEB,
          )
        end

        let!(:oldest_route_mapping) do
          RouteMappingModel.make(app: oldest_web_process_with_instances.app, process_type: oldest_web_process_with_instances.type)
        end

        let!(:oldest_label) { ProcessLabelModel.make(resource_guid: oldest_web_process_with_instances.guid) }

        it 'destroys the oldest web process and ignores the original web process' do
          expect {
            subject.scale
          }.not_to change { ProcessModel.find(guid: web_process.guid) }
          expect(ProcessModel.find(guid: oldest_web_process_with_instances.guid)).to be_nil
          expect(oldest_label.exists?).to be_falsey
        end
      end

      context 'when one of the deploying_web_process instances is starting' do
        let(:current_deploying_instances) { 3 }
        let(:all_instances_results) {
          {
            0 => { state: 'RUNNING', uptime: 50, since: 2 },
            1 => { state: 'STARTING', uptime: 50, since: 2 },
            2 => { state: 'STARTING', uptime: 50, since: 2 },
          }
        }

        it 'does not scales the process' do
          expect {
            subject.scale
          }.not_to change {
            web_process.reload.instances
          }

          expect {
            subject.scale
          }.not_to change {
            deploying_web_process.reload.instances
          }
        end
      end

      context 'when one of the deploying_web_process instances is failing' do
        let(:current_deploying_instances) { 3 }
        let(:all_instances_results) {
          {
            0 => { state: 'RUNNING', uptime: 50, since: 2 },
            1 => { state: 'FAILING', uptime: 50, since: 2 },
            2 => { state: 'FAILING', uptime: 50, since: 2 },
          }
        }

        it 'does not scale the process' do
          expect {
            subject.scale
          }.not_to change {
            web_process.reload.instances
          }

          expect {
            subject.scale
          }.not_to change {
            deploying_web_process.reload.instances
          }
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
              subject.scale
              expect(deployment.reload.last_healthy_at).to be > previous_last_healthy_at
              expect(deployment.state).to eq(DeploymentModel::DEPLOYING_STATE)
              expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
              expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYING_STATUS_REASON)
            end
          end
        end

        context 'when some instances are crashing' do
          let(:all_instances_results) {
            {
              0 => { state: 'RUNNING', uptime: 50, since: 2 },
              1 => { state: 'FAILING', uptime: 50, since: 2 },
              2 => { state: 'FAILING', uptime: 50, since: 2 },
            }
          }

          it 'changes nothing' do
            subject.scale
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
            expect {
              subject.scale
            }.to change { deployment.reload.last_healthy_at }
          end
        end

        context 'when instances are failing' do
          let(:all_instances_results) {
            {
              0 => { state: 'RUNNING', uptime: 50, since: 2 },
              1 => { state: 'FAILING', uptime: 50, since: 2 },
              2 => { state: 'FAILING', uptime: 50, since: 2 },
            }
          }

          it 'does not update the deployments last_healthy_at' do
            Timecop.travel(Time.now + 1.minute) do
              expect {
                subject.scale
              }.to_not change { deployment.reload.last_healthy_at }
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
          expect {
            subject.scale
          }.not_to change {
            web_process.reload.instances
          }

          expect {
            subject.scale
          }.not_to change {
            deploying_web_process.reload.instances
          }
        end
      end

      context 'when an error occurs while scaling a deployment' do
        let(:failing_process) { ProcessModel.make(app: web_process.app, type: 'failing', instances: 5) }
        let(:deployment) { DeploymentModel.make(app: web_process.app, deploying_web_process: failing_process, state: 'DEPLOYING') }

        before do
          allow(deployment).to receive(:app).and_raise(StandardError.new('Something real bad happened'))
        end

        it 'logs the error' do
          expect {
            subject.scale
          }.not_to change {
            failing_process.reload.instances
          }

          expect(logger).to have_received(:error).with(
            'error-scaling-deployment',
            deployment_guid: deployment.guid,
            error: 'StandardError',
            error_message: 'Something real bad happened',
            backtrace: anything
          )
        end

        it 'does not throw an error (so that other deployments can still proceed)' do
          expect {
            subject.scale
          }.not_to raise_error
        end
      end

      describe 'during an upgrade with leftover legacy webish processes' do
        let!(:deploying_web_process) do
          ProcessModel.make(
            app: web_process.app,
            type: 'web-deployment-guid-legacy',
            instances: current_deploying_instances,
            guid: 'guid-legacy',
            revision: revision,
          )
        end

        it 'scales up the coerced web process by one' do
          expect {
            subject.scale
          }.to change {
            deploying_web_process.reload.instances
          }.by(1)
        end
      end
    end

    describe '#cancel' do
      before do
        allow_any_instance_of(VCAP::CloudController::Diego::Runner).to receive(:stop)
      end

      it 'deletes the deploying process' do
        subject.cancel
        expect(ProcessModel.find(guid: deploying_web_process.guid)).to be_nil
      end

      it 'rolls back to the correct number of instances' do
        subject.cancel
        expect(web_process.reload.instances).to eq(original_web_process_instance_count)
        expect(ProcessModel.find(guid: deploying_web_process.guid)).to be_nil
      end

      it 'sets the deployment to CANCELED' do
        subject.cancel
        expect(deployment.state).to eq(DeploymentModel::CANCELED_STATE)
        expect(deployment.status_value).to eq(DeploymentModel::FINALIZED_STATUS_VALUE)
        expect(deployment.status_reason).to eq(DeploymentModel::CANCELED_STATUS_REASON)
      end

      context 'when there are interim deployments' do
        let!(:interim_deploying_web_process) {
          ProcessModel.make(
            app: app,
            created_at: an_hour_ago,
            type: ProcessTypes::WEB,
            instances: 1,
            guid: 'guid-interim'
          )
        }

        let!(:interim_route_mapping) {
          RouteMappingModel.make(
            app: web_process.app,
            process_type: interim_deploying_web_process.type
          )
        }

        it 'it scales up the most recent interim web process' do
          subject.cancel
          expect(interim_deploying_web_process.reload.instances).to eq(original_web_process_instance_count)
          expect(app.reload.web_processes.first.guid).to eq(interim_deploying_web_process.guid)
        end

        it 'sets the most recent interim web process as the only web process' do
          subject.cancel
          expect(app.reload.processes.map(&:guid)).to eq([interim_deploying_web_process.guid])
        end
      end
    end
  end
end
