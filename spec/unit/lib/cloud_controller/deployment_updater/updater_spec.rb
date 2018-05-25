require 'spec_helper'
require 'cloud_controller/deployment_updater/updater'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Updater do
    let(:web_process) { ProcessModel.make(instances: 2) }
    let(:webish_process) { ProcessModel.make(app: web_process.app, type: 'web-deployment-guid-1', instances: 5) }

    let(:web_process_2) { ProcessModel.make(instances: 2) }
    let(:webish_process_2) { ProcessModel.make(app: web_process.app, type: 'web-deployment-guid-2', instances: 5) }

    let!(:finished_deployment) { DeploymentModel.make(app: web_process_2.app, webish_process: webish_process_2, state: 'DEPLOYED') }
    let!(:deployment) { DeploymentModel.make(app: web_process.app, webish_process: webish_process, state: 'DEPLOYING') }

    let(:deployer) { DeploymentUpdater::Updater }
    let(:diego_instances_reporter) { instance_double(Diego::InstancesReporter) }
    let(:all_instances_results) {
      {
        0 => { state: 'RUNNING', uptime: 50, since: 2 },
        1 => { state: 'RUNNING', uptime: 50, since: 2 },
        2 => { state: 'RUNNING', uptime: 50, since: 2 },
      }
    }

    describe '#update' do
      before do
        instances_reporters = double(:instances_reporters)
        allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
        allow(instances_reporters).to receive(:all_instances_for_app).and_return(all_instances_results)
      end

      context 'when all original web processes are running' do
        context 'deployments in progress' do
          it 'scales the web process down by one' do
            expect {
              deployer.update
            }.to change {
              web_process.reload.instances
            }.by(-1)
          end

          it 'scales up the new web process by one' do
            expect {
              deployer.update
            }.to change {
              webish_process.reload.instances
            }.by(1)
          end
        end

        context 'the last iteration of deployments in progress' do
          let(:web_process) { ProcessModel.make(instances: 1) }
          let(:webish_process) { ProcessModel.make(app: web_process.app, type: 'web-deployment-guid-1', instances: 5) }

          it 'scales the web process down by one' do
            expect {
              deployer.update
            }.to change {
              web_process.reload.instances
            }.by(-1)
          end

          it 'does not scale up more web processes (one was created with the deployment)' do
            expect {
              deployer.update
            }.not_to change {
              webish_process.reload.instances
            }
          end
        end

        context 'deployments where web process is at zero' do
          before do
            web_process.update(instances: 0)
          end

          it 'does not scale web or webish processes' do
            deployer.update
            expect(web_process.reload.instances).to eq(0)
            expect(webish_process.reload.instances).to eq(5)
          end
        end
      end

      context 'when one of the app instances is starting' do
        let(:all_instances_results) {
          {
            0 => { state: 'RUNNING', uptime: 50, since: 2 },
            1 => { state: 'STARTING', uptime: 50, since: 2 },
            2 => { state: 'STARTING', uptime: 50, since: 2 },
          }
        }

        it 'does not scales the process' do
          expect {
            deployer.update
          }.not_to change {
            web_process.reload.instances
          }

          expect {
            deployer.update
          }.not_to change {
            webish_process.reload.instances
          }
        end
      end
    end
  end
end
