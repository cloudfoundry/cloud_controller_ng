require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DeploymentModel do
    let(:app) { AppModel.make(name: 'rolling-app') }
    let(:droplet) { DropletModel.make(app: app) }
    let(:deploying_web_process) { ProcessModel.make(health_check_timeout: 180) }

    let(:deployment) { DeploymentModel.make(app: app, droplet: droplet, deploying_web_process: deploying_web_process) }

    it 'has an app' do
      expect(deployment.app.name).to eq('rolling-app')
    end

    it 'has a droplet' do
      expect(deployment.droplet).to eq(droplet)
    end

    it 'has a deploying web process' do
      expect(deployment.deploying_web_process).to eq(deploying_web_process)
    end

    context '#processes' do
      before do
        DeploymentProcessModel.make(
          deployment: deployment,
          process_guid: deploying_web_process.guid,
          process_type: deploying_web_process.type
        )
        DeploymentProcessModel.make(
          deployment: deployment,
          process_guid: 'guid-for-deleted-process',
          process_type: 'i-do-not-exist!!!!!!!!!!'
        )
        DeploymentProcessModel.make(
          deployment: DeploymentModel.make
        )
      end

      it 'has deployment processes with the deploying web process' do
        expect(
          deployment.historical_related_processes.map(&:deployment_guid)
        ).to contain_exactly(deployment.guid, deployment.guid)

        expect(
          deployment.historical_related_processes.map(&:process_guid)
        ).to contain_exactly(deploying_web_process.guid, 'guid-for-deleted-process')

        expect(
          deployment.historical_related_processes.map(&:process_type)
        ).to contain_exactly(deploying_web_process.type, 'i-do-not-exist!!!!!!!!!!')
      end
    end

    describe '#deploying?' do
      it 'returns true if the deployment is deploying' do
        deployment.state = 'DEPLOYING'

        expect(deployment.deploying?).to be(true)
      end

      it 'returns false if the deployment has been deployed' do
        deployment.state = 'DEPLOYED'

        expect(deployment.deploying?).to be(false)
      end

      it 'returns false if the deployment is canceling' do
        deployment.state = 'CANCELING'

        expect(deployment.deploying?).to be(false)
      end

      it 'returns false if the deployment has been canceled' do
        deployment.state = 'CANCELED'

        expect(deployment.deploying?).to be(false)
      end
    end

    describe '#cancelable?' do
      it 'returns true if the deployment is DEPLOYING' do
        deployment.state = DeploymentModel::DEPLOYING_STATE

        expect(deployment.cancelable?).to be(true)
      end

      it 'returns false if the deployment is DEPLOYED' do
        deployment.state = DeploymentModel::DEPLOYED_STATE

        expect(deployment.cancelable?).to be(false)
      end

      it 'returns true if the deployment is CANCELING' do
        deployment.state = DeploymentModel::CANCELING_STATE

        expect(deployment.cancelable?).to be(true)
      end

      it 'returns false if the deployment is CANCELED' do
        deployment.state = DeploymentModel::CANCELED_STATE

        expect(deployment.cancelable?).to be(false)
      end
    end
  end
end
