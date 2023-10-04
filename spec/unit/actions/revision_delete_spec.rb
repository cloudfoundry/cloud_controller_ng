require 'spec_helper'
require 'actions/revision_delete'

module VCAP::CloudController
  RSpec.describe RevisionDelete do
    subject(:revision_delete) { RevisionDelete }

    describe '#delete' do
      let!(:revision) { RevisionModel.make }
      let!(:revision2) { RevisionModel.make }

      it 'deletes the revision' do
        revision_delete.delete([revision, revision2])

        expect(revision.exists?).to be(false), 'Expected revision to not exist, but it does'
        expect(revision2.exists?).to be(false), 'Expected revision2 to not exist, but it does'
      end

      it 'deletes associated labels' do
        label = RevisionLabelModel.make(resource_guid: revision.guid)
        expect do
          revision_delete.delete(revision)
        end.to change(RevisionLabelModel, :count).by(-1)
        expect(label).not_to exist
        expect(revision).not_to exist
      end

      it 'deletes associated annotations' do
        annotation = RevisionAnnotationModel.make(resource_guid: revision.guid)
        expect do
          revision_delete.delete(revision)
        end.to change(RevisionAnnotationModel, :count).by(-1)
        expect(annotation).not_to exist
        expect(revision).not_to exist
      end

      it 'deletes associated revision_process_commands' do
        process_command = revision.add_command_for_process_type('worker', 'foo rackup')

        expect do
          revision_delete.delete(revision)
        end.to change(RevisionProcessCommandModel, :count).by(-2)

        expect(process_command).not_to exist
        expect(revision).not_to exist
      end

      it 'deletes associated revision_sidecars' do
        # process_command = revision.add_command_for_process_type('worker', 'foo rackup')
        #
        # expect {
        #   revision_delete.delete(revision)
        # }.to change { RevisionProcessCommandModel.count }.by(-2)
        #
        # expect(process_command.exists?).to be_falsey
        # expect(revision.exists?).to be_falsey
      end
    end
  end
end
