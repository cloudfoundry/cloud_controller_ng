require 'spec_helper'
require 'actions/revision_delete'

module VCAP::CloudController
  RSpec.describe RevisionDelete do
    RSpec.shared_examples 'RevisionDelete action' do
      it 'deletes the revisions' do
        expect do
          revision_delete
        end.to change(RevisionModel, :count).by(-2)
        [revision1, revision2].each { |r| expect(r).not_to exist }
      end

      it 'deletes associated labels' do
        label1 = create(:revision_label_model, revision: revision1, key_name: 'test', value: 'bommel')
        label2 = create(:revision_label_model, revision: revision2, key_name: 'test', value: 'bommel')

        expect do
          revision_delete
        end.to change(RevisionLabelModel, :count).by(-2)
        [label1, label2].each { |l| expect(l).not_to exist }
      end

      it 'deletes associated annotations' do
        annotation1 = create(:revision_annotation_model, revision: revision1, key_name: 'test', value: 'bommel')
        annotation2 = create(:revision_annotation_model, revision: revision2, key_name: 'test', value: 'bommel')

        expect do
          revision_delete
        end.to change(RevisionAnnotationModel, :count).by(-2)
        [annotation1, annotation2].each { |a| expect(a).not_to exist }
      end

      it 'deletes associated process commands' do
        process_command1 = create(:revision_process_command_model, revision: revision1)
        process_command2 = create(:revision_process_command_model, revision: revision2)

        expect do
          revision_delete
        end.to change(RevisionProcessCommandModel, :count).by(-2)
        [process_command1, process_command2].each { |p| expect(p).not_to exist }
      end

      it 'deletes associated sidecars and sidecar process types' do
        sidecar1 = create(:revision_sidecar_model, :no_process_types, revision: revision1)
        sidecar2 = create(:revision_sidecar_model, :no_process_types, revision: revision2)
        sidecar_process_type1 = create(:revision_sidecar_process_type_model, revision_sidecar: sidecar1)
        sidecar_process_type2 = create(:revision_sidecar_process_type_model, revision_sidecar: sidecar2)

        expect do
          revision_delete
        end.to change(RevisionSidecarModel, :count).by(-2).and change(RevisionSidecarProcessTypeModel, :count).by(-2)
        [sidecar1, sidecar2, sidecar_process_type1, sidecar_process_type2].each { |s| expect(s).not_to exist }
      end
    end

    let!(:app) { create(:app_model) }
    let!(:revision1) { create(:revision_model, :no_commands, app: app) }
    let!(:revision2) { create(:revision_model, :no_commands, app: app) }

    describe '#delete' do
      it_behaves_like 'RevisionDelete action' do
        subject(:revision_delete) { RevisionDelete.delete(RevisionModel.where(id: [revision1.id, revision2.id])) }
      end
    end

    describe '#delete_for_app' do
      it_behaves_like 'RevisionDelete action' do
        subject(:revision_delete) { RevisionDelete.delete_for_app(app.guid) }
      end
    end
  end
end
