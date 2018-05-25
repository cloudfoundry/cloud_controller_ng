require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DeploymentModel do
    let(:app) { AppModel.make(name: 'rolling-app') }
    let(:droplet) { DropletModel.make(app: app) }
    let(:webish_process) { ProcessModel.make }
    let(:deployment) { DeploymentModel.make(app: app, droplet: droplet, webish_process: webish_process) }

    it 'has an app' do
      expect(deployment.app.name).to eq('rolling-app')
    end

    it 'has a droplet' do
      expect(deployment.droplet).to eq(droplet)
    end

    it 'has a webish process' do
      expect(deployment.webish_process).to eq(webish_process)
    end
  end
end
