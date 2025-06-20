require 'spec_helper'
require 'actions/deployment_continue'
require 'cloud_controller/deployment_updater/dispatcher'

module VCAP::CloudController
  RSpec.describe DeploymentContinue do
    let(:space) { Space.make }
    let(:instance_count) { 6 }
    let(:app) { AppModel.make }
    let(:droplet) { DropletModel.make(app: app, process_types: { 'web' => 'the net' }) }
    let(:original_web_process) { ProcessModelFactory.make(space: space, instances: 1, state: 'STARTED', app: app) }
    let(:deploying_web_process) { ProcessModelFactory.make(space: space, instances: instance_count, state: 'STARTED', app: app, type: 'web-deployment-deployment-guid') }
    let(:status_reason) { nil }
    let!(:deployment) do
      VCAP::CloudController::DeploymentModel.make(
        state: state,
        status_value: status_value,
        status_reason: status_reason,
        droplet: droplet,
        app: original_web_process.app,
        deploying_web_process: deploying_web_process
      )
    end

    let(:user_audit_info) { UserAuditInfo.new(user_guid: '1234', user_email: 'eric@example.com', user_name: 'eric') }

    describe '.continue' do
      context 'when the deployment is in the PAUSED state' do
        let(:state) { DeploymentModel::PAUSED_STATE }
        let(:status_value) { DeploymentModel::ACTIVE_STATUS_VALUE }
        let(:status_reason) { DeploymentModel::DEPLOYING_STATUS_REASON }

        context 'there are no steps defined' do
          it 'sets the deployments status to DEPLOYING' do
            expect(deployment.state).not_to eq(DeploymentModel::DEPLOYING_STATE)

            DeploymentContinue.continue(deployment:, user_audit_info:)
            deployment.reload

            expect(deployment.state).to eq(DeploymentModel::DEPLOYING_STATE)
            expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
            expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYING_STATUS_REASON)
          end

          it 'records an audit event for the continue deployment' do
            DeploymentContinue.continue(deployment:, user_audit_info:)

            event = VCAP::CloudController::Event.find(type: 'audit.app.deployment.continue')
            expect(event).not_to be_nil
            expect(event.actor).to eq('1234')
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq('eric@example.com')
            expect(event.actor_username).to eq('eric')
            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('app')
            expect(event.actee_name).to eq(app.name)
            expect(event.timestamp).to be
            expect(event.space_guid).to eq(app.space_guid)
            expect(event.organization_guid).to eq(app.space.organization.guid)
            expect(event.metadata).to eq({
                                           'droplet_guid' => droplet.guid,
                                           'deployment_guid' => deployment.guid
                                         })
          end
        end

        context 'and there are no remaining steps' do
          let!(:deployment) do
            VCAP::CloudController::DeploymentModel.make(
              state: state,
              status_value: status_value,
              status_reason: status_reason,
              droplet: droplet,
              app: original_web_process.app,
              deploying_web_process: deploying_web_process,
              canary_current_step: 2
            )
          end

          it 'sets the deployments status to DEPLOYING' do
            expect(deployment.state).not_to eq(DeploymentModel::DEPLOYING_STATE)

            DeploymentContinue.continue(deployment:, user_audit_info:)
            deployment.reload

            expect(deployment.state).to eq(DeploymentModel::DEPLOYING_STATE)
            expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
            expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYING_STATUS_REASON)
          end

          it 'records an audit event for the continue deployment' do
            DeploymentContinue.continue(deployment:, user_audit_info:)

            event = VCAP::CloudController::Event.find(type: 'audit.app.deployment.continue')
            expect(event).not_to be_nil
            expect(event.actor).to eq('1234')
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq('eric@example.com')
            expect(event.actor_username).to eq('eric')
            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('app')
            expect(event.actee_name).to eq(app.name)
            expect(event.timestamp).to be
            expect(event.space_guid).to eq(app.space_guid)
            expect(event.organization_guid).to eq(app.space.organization.guid)
            expect(event.metadata).to eq({
                                           'droplet_guid' => droplet.guid,
                                           'deployment_guid' => deployment.guid
                                         })
          end
        end

        context 'and there are remaining steps' do
          let!(:deployment) do
            VCAP::CloudController::DeploymentModel.make(
              state: state,
              status_value: status_value,
              status_reason: status_reason,
              droplet: droplet,
              app: original_web_process.app,
              deploying_web_process: deploying_web_process,
              canary_current_step: 1,
              canary_steps: [{ 'instance_weight' => 10 }, { 'instance_weight' => 40 }]
            )
          end

          it 'sets the deployments status to PREPAUSED' do
            expect(deployment.state).not_to eq(DeploymentModel::DEPLOYING_STATE)

            DeploymentContinue.continue(deployment:, user_audit_info:)
            deployment.reload

            expect(deployment.state).to eq(DeploymentModel::PREPAUSED_STATE)
            expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
            expect(deployment.status_reason).to eq(DeploymentModel::DEPLOYING_STATUS_REASON)
          end

          it 'increments the current canary step' do
            expect(deployment.state).not_to eq(DeploymentModel::DEPLOYING_STATE)

            DeploymentContinue.continue(deployment:, user_audit_info:)
            deployment.reload

            expect(deployment.canary_current_step).to eq(2)
          end

          it 'records an audit event for the continue deployment' do
            DeploymentContinue.continue(deployment:, user_audit_info:)

            event = VCAP::CloudController::Event.find(type: 'audit.app.deployment.continue')
            expect(event).not_to be_nil
            expect(event.actor).to eq('1234')
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq('eric@example.com')
            expect(event.actor_username).to eq('eric')
            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('app')
            expect(event.actee_name).to eq(app.name)
            expect(event.timestamp).to be
            expect(event.space_guid).to eq(app.space_guid)
            expect(event.organization_guid).to eq(app.space.organization.guid)
            expect(event.metadata).to eq({
                                           'droplet_guid' => droplet.guid,
                                           'deployment_guid' => deployment.guid
                                         })
          end
        end
      end

      context 'when the deployment is in the PREPAUSED state' do
        let(:state) { DeploymentModel::PREPAUSED_STATE }
        let(:status_value) { DeploymentModel::ACTIVE_STATUS_VALUE }
        let(:status_reason) { DeploymentModel::DEPLOYING_STATUS_REASON }

        it 'raises an error' do
          expect do
            DeploymentContinue.continue(deployment:, user_audit_info:)
          end.to raise_error(DeploymentContinue::InvalidStatus, 'Cannot continue a deployment with status: ACTIVE and reason: DEPLOYING')
        end
      end

      context 'when the deployment is in the DEPLOYING state' do
        let(:state) { DeploymentModel::DEPLOYING_STATE }
        let(:status_value) { DeploymentModel::ACTIVE_STATUS_VALUE }
        let(:status_reason) { DeploymentModel::DEPLOYING_STATUS_REASON }

        it 'raises an error' do
          expect do
            DeploymentContinue.continue(deployment:, user_audit_info:)
          end.to raise_error(DeploymentContinue::InvalidStatus, 'Cannot continue a deployment with status: ACTIVE and reason: DEPLOYING')
        end
      end

      context 'when the deployment is in the DEPLOYED state' do
        let(:state) { DeploymentModel::DEPLOYED_STATE }
        let(:status_value) { DeploymentModel::FINALIZED_STATUS_VALUE }
        let(:status_reason) { DeploymentModel::DEPLOYED_STATUS_REASON }

        it 'raises an error' do
          expect do
            DeploymentContinue.continue(deployment:, user_audit_info:)
          end.to raise_error(DeploymentContinue::InvalidStatus, 'Cannot continue a deployment with status: FINALIZED and reason: DEPLOYED')
        end
      end

      context 'when the deployment is in the CANCELED state' do
        let(:state) { DeploymentModel::CANCELED_STATE }
        let(:status_value) { DeploymentModel::FINALIZED_STATUS_VALUE }
        let(:status_reason) { DeploymentModel::CANCELED_STATUS_REASON }

        it 'raises an error' do
          expect do
            DeploymentContinue.continue(deployment:, user_audit_info:)
          end.to raise_error(DeploymentContinue::InvalidStatus, 'Cannot continue a deployment with status: FINALIZED and reason: CANCELED')
        end
      end
    end
  end
end
