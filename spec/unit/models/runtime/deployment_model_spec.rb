require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DeploymentModel do
    let(:app) { AppModel.make(name: 'rolling-app') }
    let(:deployment) { DeploymentModel.new(app: app) }

    it 'has an app' do
      expect(deployment.app.name).to eq('rolling-app')
    end
  end
end
