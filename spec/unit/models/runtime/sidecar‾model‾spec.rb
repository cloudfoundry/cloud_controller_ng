require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SidecarModel do
    let(:sidecar) { SidecarModel.make }

    describe '#process_types' do
      it 'returns the names of associated sidecar_process_types' do
        SidecarProcessTypeModel.make(type: 'web', sidecar: sidecar)
        SidecarProcessTypeModel.make(type: 'other worker', sidecar: sidecar)

        expect(sidecar.process_types).to eq ['web', 'other worker'].sort
      end
    end

    describe 'validations' do
      let(:app_model) { AppModel.make }
      let!(:sidecar) { SidecarModel.make(name: 'my_sidecar', app: app_model) }

      it 'validates unique sidecar name per app' do
        expect { SidecarModel.create(app: app_model, name: 'my_sidecar', command: 'some-command') }.
          to raise_error(Sequel::ValidationFailed, /Sidecar with name 'my_sidecar' already exists for given app/)
      end
    end
  end
end
