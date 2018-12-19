require 'spec_helper'
require 'presenters/v3/deployment_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe DeploymentPresenter do
    let(:droplet) { VCAP::CloudController::DropletModel.make }
    let(:previous_droplet) { VCAP::CloudController::DropletModel.make }
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::ProcessModel.make(guid: 'deploying-process-guid', type: 'web-deployment-guid-type') }
    let!(:deployment) do
      VCAP::CloudController::DeploymentModelTestFactory.make(
        app: app,
        droplet: droplet,
        previous_droplet: previous_droplet,
        deploying_web_process: process,
      )
    end

    describe '#to_hash' do
      it 'presents the deployment as json' do
        result = DeploymentPresenter.new(deployment).to_hash
        expect(result[:guid]).to eq(deployment.guid)
        expect(result[:state]).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATE)
        expect(result[:droplet][:guid]).to eq(droplet.guid)
        expect(result[:previous_droplet][:guid]).to eq(previous_droplet.guid)

        expect(result[:relationships][:app][:data][:guid]).to eq(deployment.app.guid)
        expect(result[:links][:self][:href]).to match(%r{/v3/deployments/#{deployment.guid}$})
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/deployments/#{deployment.guid}")
        expect(result[:links][:app][:href]).to eq("#{link_prefix}/v3/apps/#{deployment.app.guid}")
      end

      it 'includes new_processes' do
        result = DeploymentPresenter.new(deployment).to_hash
        expect(result[:new_processes]).to eq([{ guid: process.guid, type: process.type }])
      end

      context 'when the deploying web process has been destroyed by a later deployment' do
        before do
          process.destroy
        end

        it 'keeps the new_processes around for posterity' do
          result = DeploymentPresenter.new(deployment).to_hash
          expect(result[:new_processes]).to eq([{ guid: 'deploying-process-guid', type: 'web-deployment-guid-type' }])
        end
      end
    end
  end
end
