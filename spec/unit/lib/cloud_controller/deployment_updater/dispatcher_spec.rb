require 'spec_helper'
require 'cloud_controller/deployment_updater/dispatcher'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Dispatcher do
    subject(:dispatcher) { DeploymentUpdater::Dispatcher }

    let(:scaling_deployment) { DeploymentModel.make(state: DeploymentModel::DEPLOYING_STATE) }
    let(:prepaused_deployment) { DeploymentModel.make(state: DeploymentModel::PREPAUSED_STATE) }
    let(:canceling_deployment) { DeploymentModel.make(state: DeploymentModel::CANCELING_STATE) }

    let(:logger) { instance_double(Steno::Logger, info: nil, error: nil, warn: nil) }
    let(:workpool) { instance_double(WorkPool, submit: nil, drain: nil) }
    let(:updater) { instance_double(DeploymentUpdater::Updater, scale: nil, canary: nil, cancel: nil) }

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
          expect(updater).not_to have_received(:scale)
          expect(updater).not_to have_received(:cancel)
          expect(updater).not_to have_received(:canary)
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

      context 'when a deployment is in pre-paused' do
        before do
          allow(DeploymentUpdater::Updater).to receive(:new).with(prepaused_deployment, logger).and_return(updater)
        end

        it 'starts a canary deployment' do
          subject.dispatch
          expect(updater).to have_received(:canary)
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
    end
  end
end
