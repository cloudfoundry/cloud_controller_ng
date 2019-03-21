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
        expect(revision.labels.map { |label| { key: label.key_name, value: label.value } }).to match_array([{ key: 'freaky', value: 'wednesday' }])
        expect(revision.annotations.map { |a| { key: a.key, value: a.value } }).
          to match_array([{ key: 'tokyo', value: 'grapes' }])
      end
    end
  end
end
