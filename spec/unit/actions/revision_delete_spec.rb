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

        expect(revision.exists?).to eq(false), 'Expected revision to not exist, but it does'
        expect(revision2.exists?).to eq(false), 'Expected revision2 to not exist, but it does'
      end
    end
  end
end
