require 'spec_helper'
require 'actions/deployment_delete'

module VCAP::CloudController
  RSpec.describe DeploymentDelete do
    RSpec.shared_examples 'DeploymentDelete action' do
      it 'deletes the deployments' do
        expect do
          deployment_delete
        end.to change(DeploymentModel, :count).by(-2)
        [deployment1, deployment2].each { |d| expect(d).not_to exist }
      end

      it 'deletes associated labels' do
        label1 = DeploymentLabelModel.make(deployment: deployment1, key_name: 'test', value: 'bommel')
        label2 = DeploymentLabelModel.make(deployment: deployment2, key_name: 'test', value: 'bommel')

        expect do
          deployment_delete
        end.to change(DeploymentLabelModel, :count).by(-2)
        [label1, label2].each { |l| expect(l).not_to exist }
      end

      it 'deletes associated annotations' do
        annotation1 = DeploymentAnnotationModel.make(deployment: deployment1, key_name: 'test', value: 'bommel')
        annotation2 = DeploymentAnnotationModel.make(deployment: deployment2, key_name: 'test', value: 'bommel')

        expect do
          deployment_delete
        end.to change(DeploymentAnnotationModel, :count).by(-2)
        [annotation1, annotation2].each { |a| expect(a).not_to exist }
      end

      it 'deletes associated historical processes' do
        process1 = DeploymentProcessModel.make(deployment: deployment1)
        process2 = DeploymentProcessModel.make(deployment: deployment2)

        expect do
          deployment_delete
        end.to change(DeploymentProcessModel, :count).by(-2)
        [process1, process2].each { |p| expect(p).not_to exist }
      end
    end

    let!(:app) { AppModel.make }
    let!(:deployment1) { DeploymentModel.make(app:) }
    let!(:deployment2) { DeploymentModel.make(app:) }

    describe '#delete' do
      it_behaves_like 'DeploymentDelete action' do
        subject(:deployment_delete) { DeploymentDelete.delete(DeploymentModel.where(id: [deployment1.id, deployment2.id])) }
      end
    end

    describe '#delete_for_app' do
      it_behaves_like 'DeploymentDelete action' do
        subject(:deployment_delete) { DeploymentDelete.delete_for_app(app.guid) }
      end
    end
  end
end
