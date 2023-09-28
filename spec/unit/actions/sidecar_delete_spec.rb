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

        expect(sidecar.exists?).to be(false), 'Expected sidecar to not exist, but it does'
        expect(sidecar2.exists?).to be(false), 'Expected sidecar2 to not exist, but it does'
      end

      it 'deletes associated sidecar_process_commands' do
        process_type = SidecarProcessTypeModel.make(sidecar:)

        expect do
          sidecar_delete.delete(sidecar)
        end.to change(SidecarProcessTypeModel, :count).by(-1)

        expect(process_type).not_to exist
        expect(sidecar).not_to exist
      end
    end
  end
end
