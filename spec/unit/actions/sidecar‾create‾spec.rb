require 'spec_helper'
require 'actions/sidecar_create'

module VCAP::CloudController
  RSpec.describe SidecarCreate do
    let(:app) { AppModel.make }
    let(:params) do
      {
        name: 'sidecar-name',
        command: './start',
        process_types: ['web', 'worker'],
      }
    end
    let(:message) { SidecarCreateMessage.new(params) }

    describe '.create' do
      it 'creates a sidecar for the app' do
        sidecar = nil
        expect {
          sidecar = SidecarCreate.create(app.guid, message)
        }.to change { SidecarModel.where(app: app).count }.by(1)

        expect(sidecar.app_guid).to eq(app.guid)
        expect(sidecar.name).to eq('sidecar-name')
        expect(sidecar.command).to eq('./start')
        expect(sidecar.process_types).to eq(['web', 'worker'])
      end
    end
  end
end
