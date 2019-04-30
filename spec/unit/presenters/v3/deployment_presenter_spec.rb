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
            )
        end

        it 'presents the deployment as json' do
          app.update(revisions_enabled: true)

          result = DeploymentPresenter.new(deployment).to_hash
          expect(result[:guid]).to eq(deployment.guid)
          expect(result[:state]).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATE)
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

      describe 'failing state' do
        before do
          TestConfig.override({ default_health_check_timeout: 60 })
        end

        let!(:deployment) do
          VCAP::CloudController::DeploymentModelTestFactory.make(
            app: app,
            state: VCAP::CloudController::DeploymentModel::DEPLOYING_STATE,
            droplet: droplet,
            previous_droplet: previous_droplet,
            deploying_web_process: process,
            revision_guid: 'totes-a-guid',
            revision_version: 96,
            last_healthy_at: last_healthy_at
          )
        end

        context 'when the app has not yet started' do
          let(:last_healthy_at) { nil }
          it 'returns the deployment state' do
            result = DeploymentPresenter.new(deployment).to_hash
            expect(result[:state]).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATE)
          end
        end

        context 'when the last successful healthcheck is within 2x the timeout' do
          let(:last_healthy_at) { 30.seconds.ago }
          it 'returns the deployment state' do
            result = DeploymentPresenter.new(deployment).to_hash
            expect(result[:state]).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATE)
          end
        end

        context 'when the last successful healthcheck has been longer than 2x the timeout' do
          let(:last_healthy_at) { 121.seconds.ago }
          it 'reports the deployment is failing' do
            result = DeploymentPresenter.new(deployment).to_hash
            expect(result[:state]).to eq(DeploymentPresenter::FAILING_STATE)
          end
        end
      end
    end
  end
end
