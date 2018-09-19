require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DeploymentModel do
    let(:app) { AppModel.make(name: 'rolling-app') }
    let(:droplet) { DropletModel.make(app: app) }
    let(:deploying_web_process) { ProcessModel.make }
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
  end
end
