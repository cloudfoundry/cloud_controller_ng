require 'spec_helper'
require 'fetchers/app_revisions_fetcher'

module VCAP::CloudController
  RSpec.describe AppRevisionsFetcher do
    let(:fetcher) { AppRevisionsFetcher }

    describe '#fetch' do
      before do
        RevisionModel.dataset.destroy
      end

      let!(:app) { AppModel.make }
      let!(:revision1) { RevisionModel.make(version: 21, app: app) }
      let!(:revision2) { RevisionModel.make(version: 34, app: app) }

      let(:message) { AppRevisionsListMessage.from_params(filters) }
      subject { fetcher.fetch(app, message) }

      context 'when no filters are specified' do
        let(:filters) { {} }

        it 'fetches all the revisions' do
          expect(subject).to match_array([revision1, revision2])
        end
      end

      context 'when the revisions are filtered' do
        let(:filters) { { versions: [revision1.version] } }

        it 'returns all of the desired revisions' do
          expect(subject).to include(revision1)
          expect(subject).to_not include(revision2)
        end
      end

      context 'when a label_selector is provided' do
        let(:message) { AppRevisionsListMessage.from_params({ 'label_selector' => 'key=value' }) }
        let!(:revision1label) { RevisionLabelModel.make(key_name: 'key', value: 'value', revision: revision1) }
        let!(:revision2label) { RevisionLabelModel.make(key_name: 'key2', value: 'value2', revision: revision2) }

        it 'returns the correct set of revisions' do
          results = fetcher.fetch(app, message).all
          expect(results).to contain_exactly(revision1)
        end
      end
    end
  end
end
