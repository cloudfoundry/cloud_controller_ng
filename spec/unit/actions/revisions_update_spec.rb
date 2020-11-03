require 'spec_helper'
require 'actions/revisions_update'

module VCAP::CloudController
  RSpec.describe RevisionsUpdate do
    subject(:revision_update) { RevisionsUpdate.new }

    describe '#update' do
      let(:body) do
        {
          metadata: {
            labels: {
              freaky: 'wednesday',
            },
            annotations: {
              tokyo: 'grapes'
            },
          },
        }
      end
      let(:revision) { RevisionModel.make }
      let(:message) { RevisionsUpdateMessage.new(body) }

      it 'updates the revision metadata' do
        expect(message).to be_valid
        revision_update.update(revision, message)

        revision.reload
        expect(revision).to have_labels({ key: 'freaky', value: 'wednesday' })
        expect(revision).to have_annotations({ key: 'tokyo', value: 'grapes' })
      end
    end
  end
end
