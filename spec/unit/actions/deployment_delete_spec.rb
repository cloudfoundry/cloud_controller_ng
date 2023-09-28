require 'spec_helper'
require 'actions/deployment_delete'

module VCAP::CloudController
  RSpec.describe DeploymentDelete do
    subject(:deployment_delete) { DeploymentDelete }

    describe '#delete' do
      let!(:deployment) { DeploymentModel.make }
      let!(:deployment2) { DeploymentModel.make }

      it 'deletes and cancels the deployment record' do
        deployment_delete.delete([deployment, deployment2])

        expect(deployment.exists?).to be(false), 'Expected deployment to not exist, but it does'
        expect(deployment2.exists?).to be(false), 'Expected deployment2 to not exist, but it does'
      end

      it 'deletes associated labels' do
        label = DeploymentLabelModel.make(resource_guid: deployment.guid)
        expect do
          deployment_delete.delete([deployment])
        end.to change(DeploymentLabelModel, :count).by(-1)
        expect(label).not_to exist
        expect(deployment).not_to exist
      end

      it 'deletes associated annotations' do
        annotation = DeploymentAnnotationModel.make(resource_guid: deployment.guid)
        expect do
          deployment_delete.delete([deployment])
        end.to change(DeploymentAnnotationModel, :count).by(-1)
        expect(annotation).not_to exist
        expect(deployment).not_to exist
      end

      it 'deletes associated historical processes' do
        process = DeploymentProcessModel.make(deployment:)
        expect do
          deployment_delete.delete([deployment])
        end.to change(DeploymentProcessModel, :count).by(-1)
        expect(process).not_to exist
        expect(deployment).not_to exist
      end
    end
  end
end
