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
        process_type1 = create(:sidecar_process_type_model, sidecar: sidecar1)
        process_type2 = create(:sidecar_process_type_model, sidecar: sidecar2)

        expect do
          sidecar_delete
        end.to change(SidecarProcessTypeModel, :count).by(-2)
        [process_type1, process_type2].each { |p| expect(p).not_to exist }
      end
    end

    let!(:app) { create(:app_model) }
    let!(:sidecar1) { create(:sidecar_model, app:) }
    let!(:sidecar2) { create(:sidecar_model, app:) }

    describe '#delete' do
      it_behaves_like 'SidecarDelete action' do
        subject(:sidecar_delete) { SidecarDelete.delete(SidecarModel.where(id: [sidecar1.id, sidecar2.id])) }
      end
    end

    describe '#delete_for_app' do
      it_behaves_like 'SidecarDelete action' do
        subject(:sidecar_delete) { SidecarDelete.delete_for_app(app.guid) }
      end
    end
  end
end
