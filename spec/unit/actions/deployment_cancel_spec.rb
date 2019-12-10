require 'spec_helper'
require 'actions/deployment_cancel'
require 'cloud_controller/deployment_updater/dispatcher'

module VCAP::CloudController
  RSpec.describe DeploymentCancel do
    let(:space) { Space.make }
    let(:instance_count) { 6 }
    let(:app) { AppModel.make }
    let(:old_droplet) { DropletModel.make(app: app, process_types: { 'web' => 'the internet' }) }
    let(:new_droplet) { DropletModel.make(app: app, process_types: { 'web' => 'the net' }) }
    let(:original_web_process) { ProcessModelFactory.make(space: space, instances: 1, state: 'STARTED', app: app) }
    let(:deploying_web_process) { ProcessModelFactory.make(space: space, instances: instance_count, state: 'STARTED', app: app, type: 'web-deployment-deployment-guid') }
    let(:status_reason) { nil }
    let!(:deployment) do
      VCAP::CloudController::DeploymentModel.make(
        state: state,
        status_value: status_value,
        status_reason: status_reason,
        app: original_web_process.app,
        deploying_web_process: deploying_web_process,
        droplet: new_droplet,
        previous_droplet: old_droplet
      )
    end

    before do
      app.update(droplet: new_droplet)
    end

    let(:user_audit_info) { UserAuditInfo.new(user_guid: '1234', user_email: 'eric@example.com', user_name: 'eric') }

    describe '.cancel' do
      context 'when the deployment is in the DEPLOYING state' do
        let(:state) { DeploymentModel::DEPLOYING_STATE }
        let(:status_value) { DeploymentModel::ACTIVE_STATUS_VALUE }
        let(:status_reason) { DeploymentModel::DEPLOYING_STATUS_REASON }

        it 'sets the deployments status to CANCELING' do
          expect(deployment.state).to_not eq(DeploymentModel::CANCELING_STATE)

          DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
          deployment.reload

          expect(deployment.state).to eq(DeploymentModel::CANCELING_STATE)
          expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
          expect(deployment.status_reason).to eq(DeploymentModel::CANCELING_STATUS_REASON)
        end

        it "resets the app's current droplet to the previous droplet from the deploy" do
          DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
          expect(app.reload.droplet).to eq(old_droplet)
        end

        it 'records an audit event for the cancelled deployment' do
          DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)

          event = VCAP::CloudController::Event.find(type: 'audit.app.deployment.cancel')
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
            'droplet_guid' => new_droplet.guid,
            'deployment_guid' => deployment.guid
          })
        end

        context 'when setting the current droplet errors' do
          before do
            app_assign_droplet = instance_double(AppAssignDroplet)
            allow(app_assign_droplet).to receive(:assign).and_raise(AppAssignDroplet::Error.new('ahhhh!'))
            allow(AppAssignDroplet).to receive(:new).and_return(app_assign_droplet)
          end

          it 'raises the error' do
            expect {
              DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
            }.to raise_error(DeploymentCancel::SetCurrentDropletError, 'ahhhh!')
          end
        end

        context 'when the previous droplet of the deployment is nil' do
          let(:old_droplet) { nil }

          it 'raises the error' do
            expect {
              DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
            }.to raise_error(DeploymentCancel::SetCurrentDropletError, /Unable to assign current droplet\./)
          end
        end

        context 'when the previous droplet no longer exists' do
          it 'raises the error' do
            old_droplet.destroy
            expect {
              DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
            }.to raise_error(DeploymentCancel::SetCurrentDropletError, /Unable to assign current droplet\./)
          end
        end
      end

      context 'when the deployment is in the CANCELING state' do
        let(:state) { DeploymentModel::CANCELING_STATE }
        let(:status_value) { DeploymentModel::ACTIVE_STATUS_VALUE }
        let(:status_reason) { DeploymentModel::CANCELING_STATUS_REASON }

        it 'does *not* fail (idempotent canceling)' do
          DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
          deployment.reload

          expect(deployment.state).to eq(DeploymentModel::CANCELING_STATE)
          expect(deployment.status_value).to eq(DeploymentModel::ACTIVE_STATUS_VALUE)
          expect(deployment.status_reason).to eq(DeploymentModel::CANCELING_STATUS_REASON)
        end
      end

      context 'when the deployment is in the DEPLOYED state' do
        let(:state) { DeploymentModel::DEPLOYED_STATE }
        let(:status_value) { DeploymentModel::FINALIZED_STATUS_VALUE }
        let(:status_reason) { DeploymentModel::DEPLOYED_STATUS_REASON }

        it 'raises an error' do
          expect {
            DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
          }.to raise_error(DeploymentCancel::InvalidStatus, 'Cannot cancel a deployment with status: FINALIZED and reason: DEPLOYED')
        end
      end

      context 'when the deployment is in the CANCELED state' do
        let(:state) { DeploymentModel::CANCELED_STATE }
        let(:status_value) { DeploymentModel::FINALIZED_STATUS_VALUE }
        let(:status_reason) { DeploymentModel::CANCELED_STATUS_REASON }

        it 'raises an error' do
          expect {
            DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
          }.to raise_error(DeploymentCancel::InvalidStatus, 'Cannot cancel a deployment with status: FINALIZED and reason: CANCELED')
        end
      end
    end
  end
end
