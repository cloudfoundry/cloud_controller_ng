require 'spec_helper'
require 'actions/deployment_cancel'
require 'cloud_controller/deployment_updater/updater'

module VCAP::CloudController
  RSpec.describe DeploymentCancel do
    let(:space) { Space.make }
    let(:instance_count) { 6 }
    let(:app) { AppModel.make }
    let(:old_droplet) { DropletModel.make(app: app, process_types: { 'web' => 'the internet' }) }
    let(:new_droplet) { DropletModel.make(app: app, process_types: { 'web' => 'the net' }) }
    let(:original_web_process) { ProcessModelFactory.make(space: space, instances: 1, state: 'STARTED', app: app) }
    let(:deploying_web_process) { ProcessModelFactory.make(space: space, instances: instance_count, state: 'STARTED', app: app, type: 'web-deployment-deployment-guid') }
    let!(:deployment) do
      VCAP::CloudController::DeploymentModel.make(
        state: state,
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

        it 'sets the deployments state to CANCELED' do
          expect(deployment.state).to_not eq('CANCELED')
          DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
          expect(deployment.reload.state).to eq('CANCELED')
        end

        it "resets the app's current droplet to the previous droplet from the deploy" do
          DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
          expect(app.reload.droplet).to eq(old_droplet)
        end

        context 'when setting the current droplet errors' do
          before do
            set_current_droplet = instance_double(SetCurrentDroplet)
            allow(set_current_droplet).to receive(:update_to).and_raise(SetCurrentDroplet::Error.new('ahhhh!'))
            allow(SetCurrentDroplet).to receive(:new).and_return(set_current_droplet)
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

        context 'when routes are mapped' do
          let(:deploying_process_route) { Route.make(space: deploying_web_process.space) }

          it 'deletes the deploying web process and associated routes' do
            RouteMappingModel.make(app: deploying_web_process.app, route: deploying_process_route,
                                   process_type: deploying_web_process.type)
            DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
            expect(ProcessModel.find(guid: deploying_web_process.guid)).to be_nil
            expect(RouteMappingModel.find(app: app, process_type: deploying_web_process.type)).to be_nil
          end
        end

        describe 'inferring the correct number of instances' do
          context 'when there are n + 1 process instances' do
            context 'when there is 1 original instance' do
              let(:original_web_process) { ProcessModelFactory.make(space: space, instances: 1, state: 'STARTED', app: app) }
              let(:deploying_web_process) { ProcessModelFactory.make(space: space, instances: 6, state: 'STARTED', app: app, type: 'web-deployment-deployment-guid') }

              it 'rolls back to the correct number of instances' do
                DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
                expect(original_web_process.reload.instances).to eq(6)
                expect(deploying_web_process.exists?).to be false
              end
            end

            context 'when there is more than 1 original' do
              let(:original_web_process) { ProcessModelFactory.make(space: space, instances: 2, state: 'STARTED', app: app) }
              let(:deploying_web_process) { ProcessModelFactory.make(space: space, instances: 5, state: 'STARTED', app: app, type: 'web-deployment-deployment-guid') }

              it 'rolls back to the correct number of instances' do
                DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
                expect(original_web_process.reload.instances).to eq(6)
                expect(deploying_web_process.exists?).to be false
              end
            end
          end

          context 'when there are n total process instances (because the deployment is fully scaled, but not yet DEPLOYED)' do
            let(:original_web_process) { ProcessModelFactory.make(space: space, instances: 0, state: 'STARTED', app: app) }
            let(:deploying_web_process) { ProcessModelFactory.make(space: space, instances: 6, state: 'STARTED', app: app, type: 'web-deployment-deployment-guid') }

            it 'rolls back to the correct number of instances' do
              DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
              expect(original_web_process.reload.instances).to eq(6)
              expect(deploying_web_process.exists?).to be false
            end
          end
        end
      end

      context 'when the deployment is in the DEPLOYED state' do
        let(:state) { DeploymentModel::DEPLOYED_STATE }

        it 'raises an error' do
          expect {
            DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
          }.to raise_error(DeploymentCancel::InvalidState, 'Cannot cancel a DEPLOYED deployment')
        end
      end

      context 'when the deployment is in the CANCELED state' do
        let(:state) { DeploymentModel::CANCELED_STATE }

        it 'raises an error' do
          expect {
            DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
          }.to raise_error(DeploymentCancel::InvalidState, 'Cannot cancel a CANCELED deployment')
        end
      end
    end
  end
end
