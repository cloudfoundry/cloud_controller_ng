require 'spec_helper'
require 'actions/sidecar_delete'

module VCAP::CloudController
  RSpec.describe SidecarDelete do
    subject(:sidecar_delete) { SidecarDelete }

    describe '.delete' do
      let!(:sidecar) { SidecarModel.make }
      let!(:sidecar2) { SidecarModel.make }

      it 'deletes the sidecars' do
        sidecar_delete.delete([sidecar, sidecar2])

        expect(sidecar.exists?).to eq(false), 'Expected sidecar to not exist, but it does'
        expect(sidecar2.exists?).to eq(false), 'Expected sidecar2 to not exist, but it does'
      end

      it 'deletes associated sidecar_process_commands' do
        process_type = SidecarProcessTypeModel.make(sidecar: sidecar)

        expect {
          sidecar_delete.delete(sidecar)
        }.to change { SidecarProcessTypeModel.count }.by(-1)

        expect(process_type.exists?).to be_falsey
        expect(sidecar.exists?).to be_falsey
      end
    end
  end
end
