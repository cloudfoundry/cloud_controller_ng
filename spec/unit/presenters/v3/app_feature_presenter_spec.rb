require 'spec_helper'
require 'presenters/v3/app_ssh_feature_presenter'
require 'presenters/v3/app_file_based_service_bindings_feature_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe AppSshFeaturePresenter do
    let(:app) { VCAP::CloudController::AppModel.make }

    describe '#to_hash' do
      it 'presents the app feature as json' do
        result = AppSshFeaturePresenter.new(app).to_hash
        expect(result[:name]).to eq('ssh')
        expect(result[:description]).to eq('Enable SSHing into the app.')
        expect(result[:enabled]).to eq(app.enable_ssh)
      end
    end
  end

  RSpec.describe AppFileBasedServiceBindingsFeaturePresenter do
    let(:app) { VCAP::CloudController::AppModel.make }

    describe '#to_hash' do
      it 'presents the app feature as json' do
        result = AppFileBasedServiceBindingsFeaturePresenter.new(app).to_hash
        expect(result[:name]).to eq('file-based-service-bindings')
        expect(result[:description]).to eq('Enable file-based service bindings for the app')
        expect(result[:enabled]).to eq(app.file_based_service_bindings_enabled)
      end
    end
  end
end
