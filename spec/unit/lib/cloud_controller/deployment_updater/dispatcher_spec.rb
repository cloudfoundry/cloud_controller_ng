require 'spec_helper'
require 'cloud_controller/deployment_updater/dispatcher'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Dispatcher do
    subject(:dispatcher) { DeploymentUpdater::Dispatcher }

    let(:scaling_deployment) { DeploymentModel.make(state: DeploymentModel::DEPLOYING_STATE) }
    let(:canceling_deployment) { DeploymentModel.make(state: DeploymentModel::CANCELING_STATE) }

    let(:logger) { instance_double(Steno::Logger, info: nil, error: nil, warn: nil) }
    let(:workpool) { instance_double(WorkPool, submit: nil, drain: nil) }
    let(:updater) { instance_double(DeploymentUpdater::Updater, scale: nil, cancel: nil) }

    describe '.dispatch' do
      before do
        allow(WorkPool).to receive(:new).and_return(workpool)
        allow(Steno).to receive(:logger).and_return(logger)
        allow(workpool).to receive(:submit) do |*args, &block|
          block.call(*args)
        end
      end

      context 'when there are no deployments' do
        it 'does nothing' do
          subject.dispatch
          expect(updater).to_not have_received(:scale)
          expect(updater).to_not have_received(:cancel)
        end
      end

      context 'when a deployment is in flight' do
        before do
          allow(DeploymentUpdater::Updater).to receive(:new).with(scaling_deployment, logger).and_return(updater)
        end
        it 'scales the deployment' do
          subject.dispatch
          expect(updater).to have_received(:scale)
        end
      end

      context 'when a deployment is being canceled' do
        before do
          allow(DeploymentUpdater::Updater).to receive(:new).with(canceling_deployment, logger).and_return(updater)
        end
        it 'cancels the deployment' do
          subject.dispatch
          expect(updater).to have_received(:cancel)
        end
      end

      context 'when a deployment is missing its deploying_web_process' do
        let!(:scaling_deployment) { DeploymentModel.make(state: DeploymentModel::DEPLOYING_STATE, deploying_web_process: nil) }
        let!(:deployment_process_model) { DeploymentProcessModel.make(deployment: scaling_deployment, process_guid: 'some_guid') }

        before do
          allow(DeploymentUpdater::Updater).to receive(:new).with(scaling_deployment, logger).and_return(updater)
        end

        it 'finalizes the deployment, sets the status, and logs' do
          subject.dispatch

          deployment = scaling_deployment.reload
          expect(logger).to have_received(:warn).with(
            'finalized-degenerate-deployment',
            deployment: deployment.guid,
            app: deployment.app.guid,
          )
          expect(deployment.status_value).to eq(DeploymentModel::FINALIZED_STATUS_VALUE)
          expect(deployment.status_reason).to eq(DeploymentModel::DEGENERATE_STATUS_REASON)
        end

        it 'does not scale the deployment' do
          subject.dispatch
          expect(updater).to_not have_received(:scale)
        end
      end
    end
  end
end
