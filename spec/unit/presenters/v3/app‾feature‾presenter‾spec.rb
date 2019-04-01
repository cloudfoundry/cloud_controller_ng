require 'spec_helper'
require 'presenters/v3/app_ssh_feature_presenter'

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
end
