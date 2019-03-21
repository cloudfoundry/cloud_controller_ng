require 'spec_helper'
require 'presenters/v3/sidecar_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe SidecarPresenter do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:sidecar) do
      FactoryBot.create(:sidecar,
        app: app_model,
        name: 'my-sidecar',
        command: './start-me-up',
      )
    end
    let!(:web_sidecar_process_type) { VCAP::CloudController::SidecarProcessTypeModel.create(name: 'web', sidecar_guid: sidecar.guid) }
    let!(:worker_sidecar_process_type) { VCAP::CloudController::SidecarProcessTypeModel.create(name: 'worker', sidecar_guid: sidecar.guid) }

    describe '#to_hash' do
      it 'presents the sidecar as json' do
        result = SidecarPresenter.new(sidecar).to_hash
        expect(result[:guid]).to eq(sidecar.guid)
        expect(result[:name]).to eq('my-sidecar')
        expect(result[:command]).to eq('./start-me-up')
        expect(result[:process_types]).to eq(['web', 'worker'])
        expect(result[:created_at]).to eq(sidecar.created_at)
        expect(result[:updated_at]).to eq(sidecar.updated_at)
        expect(result[:relationships][:app][:data][:guid]).to eq(app_model.guid)
      end
    end
  end
end
