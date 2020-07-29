require 'spec_helper'
require 'cloud_controller/diego/lifecycles/app_kpack_lifecycle'
require_relative 'app_lifecycle_shared'

module VCAP::CloudController
  RSpec.describe AppKpackLifecycle do
    subject(:lifecycle) { AppKpackLifecycle.new(message) }
    let(:message) { VCAP::CloudController::AppCreateMessage.new(request) }
    let(:request) { { lifecycle: { type: 'kpack', data: lifecycle_request_data } } }
    let(:lifecycle_request_data) { {} }

    describe '#update_lifecycle_data_model' do
      let(:app) { AppModel.make(:kpack) }
      let(:lifecycle_request_data) { { buildpacks: ['paketo_buildpack/go'] } }

      it 'updates the KpackLifecycleDataModel' do
        lifecycle.update_lifecycle_data_model(app)
        app.reload
        data_model = app.lifecycle_data

        expect(data_model.buildpacks).to eq(['paketo_buildpack/go'])
      end
    end
  end
end
