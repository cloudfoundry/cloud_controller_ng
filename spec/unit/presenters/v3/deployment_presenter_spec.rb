require 'spec_helper'
require 'presenters/v3/deployment_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe DeploymentPresenter do
    let(:droplet) { VCAP::CloudController::DropletModel.make }
    let(:previous_droplet) { VCAP::CloudController::DropletModel.make }
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::ProcessModel.make(guid: 'deploying-process-guid', type: 'web-deployment-guid-type') }
    let(:deployment_state) { VCAP::CloudController::DeploymentModel::DEPLOYING_STATE }
    let!(:deployment) do
      VCAP::CloudController::DeploymentModelTestFactory.make(
        app: app,
        droplet: droplet,
        previous_droplet: previous_droplet,
        deploying_web_process: process,
        last_healthy_at: '2019-07-12 19:01:54',
        state: deployment_state,
        status_value: VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
        status_reason: VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON
      )
    end

    describe '#to_hash' do
      it 'presents the deployment as json' do
        result = DeploymentPresenter.new(deployment).to_hash
        expect(result[:guid]).to eq(deployment.guid)

        expect(result[:status][:value]).to eq(VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE)
        expect(result[:status][:reason]).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON)
        expect(result[:status][:details][:last_successful_healthcheck]).to eq('2019-07-12 19:01:54')

        expect(result[:strategy]).to eq('rolling')

        expect(result[:droplet][:guid]).to eq(droplet.guid)
        expect(result[:previous_droplet][:guid]).to eq(previous_droplet.guid)

        expect(result[:relationships][:app][:data][:guid]).to eq(deployment.app.guid)
        expect(result[:links][:self][:href]).to match(%r{/v3/deployments/#{deployment.guid}$})
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/deployments/#{deployment.guid}")
        expect(result[:links][:app][:href]).to eq("#{link_prefix}/v3/apps/#{deployment.app.guid}")
        expect(result[:metadata]).to eq({ annotations: {}, labels: {} })
        expect(result).to have_key(:revision)
        expect(result[:revision]).to be_nil
      end

      it 'includes new_processes' do
        result = DeploymentPresenter.new(deployment).to_hash
        expect(result[:new_processes]).to eq([{ guid: process.guid, type: process.type }])
      end

      context 'when the deployment has revision fields' do
        let!(:deployment) do
          VCAP::CloudController::DeploymentModelTestFactory.make(
            app: app,
            droplet: droplet,
            previous_droplet: previous_droplet,
            deploying_web_process: process,
            revision_guid: 'totes-a-guid',
            revision_version: 96,
            state: VCAP::CloudController::DeploymentModel::DEPLOYING_STATE,
            status_value: VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
            status_reason: VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON
          )
        end

        it 'presents the deployment as json' do
          app.update(revisions_enabled: true)

          result = DeploymentPresenter.new(deployment).to_hash
          expect(result[:guid]).to eq(deployment.guid)

          expect(result[:status][:value]).to eq(VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE)
          expect(result[:status][:reason]).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON)

          expect(result[:droplet][:guid]).to eq(droplet.guid)
          expect(result[:previous_droplet][:guid]).to eq(previous_droplet.guid)

          expect(result[:relationships][:app][:data][:guid]).to eq(deployment.app.guid)
          expect(result[:links][:self][:href]).to match(%r{/v3/deployments/#{deployment.guid}$})
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/deployments/#{deployment.guid}")
          expect(result[:links][:app][:href]).to eq("#{link_prefix}/v3/apps/#{deployment.app.guid}")
          expect(result[:metadata]).to eq({ annotations: {}, labels: {} })
          expect(result[:revision]).to eq({ guid: 'totes-a-guid', version: 96 })
        end

        it 'presents the revision field as nil when revisions are not enabled for the app' do
          app.update(revisions_enabled: false)

          result = DeploymentPresenter.new(deployment).to_hash
          expect(result).to have_key(:revision)
          expect(result[:revision]).to be_nil
        end
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

      describe 'cancel link' do
        context 'when the deployment is cancelable' do
          let(:deployment_state) { VCAP::CloudController::DeploymentModel::DEPLOYING_STATE }

          it 'presents the cancel link' do
            result = DeploymentPresenter.new(deployment).to_hash

            expect(result[:links][:cancel][:href]).to eq("#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel")
            expect(result[:links][:cancel][:method]).to eq('POST')
          end
        end

        context 'when the deployment is NOT cancelable' do
          let(:deployment_state) { VCAP::CloudController::DeploymentModel::CANCELED_STATE }

          it 'does NOT present the cancel link' do
            result = DeploymentPresenter.new(deployment).to_hash

            expect(result[:links][:cancel]).to be_nil
          end
        end
      end
    end
  end
end
