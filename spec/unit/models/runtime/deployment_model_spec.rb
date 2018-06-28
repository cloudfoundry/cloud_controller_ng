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
  end
end
