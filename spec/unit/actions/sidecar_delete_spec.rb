require 'spec_helper'
require 'actions/sidecar_delete'

module VCAP::CloudController
  RSpec.describe SidecarDelete do
    RSpec.shared_examples 'SidecarDelete action' do
      it 'deletes the sidecars' do
        expect do
          sidecar_delete
        end.to change(SidecarModel, :count).by(-2)
        [sidecar1, sidecar2].each { |s| expect(s).not_to exist }
      end

      it 'deletes associated sidecar process types' do
        process_type1 = SidecarProcessTypeModel.make(sidecar: sidecar1)
        process_type2 = SidecarProcessTypeModel.make(sidecar: sidecar2)

        expect do
          sidecar_delete
        end.to change(SidecarProcessTypeModel, :count).by(-2)
        [process_type1, process_type2].each { |p| expect(p).not_to exist }
      end
    end

    let!(:app) { AppModel.make }
    let!(:sidecar1) { SidecarModel.make(app:) }
    let!(:sidecar2) { SidecarModel.make(app:) }

    describe '#delete' do
      it_behaves_like 'SidecarDelete action' do
        subject(:sidecar_delete) { SidecarDelete.delete([sidecar1, sidecar2]) }
      end
    end

    describe '#delete_for_app' do
      it_behaves_like 'SidecarDelete action' do
        subject(:sidecar_delete) { SidecarDelete.delete_for_app(app.guid) }
      end
    end
  end
end
