require 'spec_helper'
require 'fetchers/app_revisions_list_fetcher'

module VCAP::CloudController
  RSpec.describe AppRevisionsListFetcher do
    let(:fetcher) { AppRevisionsListFetcher }
    let!(:app) { create(:app_model) }

    let(:expired_droplet) { create(:droplet_model, app: app, state: DropletModel::EXPIRED_STATE, set_as_current_droplet: false) }
    let(:staged_droplet) { create(:droplet_model, app: app, state: DropletModel::STAGED_STATE, set_as_current_droplet: false) }

    let!(:revision1) { create(:revision_model, version: 21, droplet: staged_droplet, app: app) }
    let!(:revision2) { create(:revision_model, version: 34, droplet: expired_droplet, app: app) }

    describe '#fetch' do
      let(:message) { AppRevisionsListMessage.from_params(filters) }

      subject { fetcher.fetch(app, message) }

      context 'when no filters are specified' do
        let(:filters) { {} }

        it 'fetches all the revisions' do
          expect(subject).to contain_exactly(revision1, revision2)
        end
      end

      context 'when the revisions are filtered on version' do
        let(:filters) { { versions: [revision1.version] } }

        it 'returns all of the desired revisions' do
          expect(subject).to include(revision1)
          expect(subject).not_to include(revision2)
        end
      end

      context 'when the revisions are filtered on deployable' do
        let(:filters) { { deployable: true } }

        it 'returns all of the desired revisions' do
          expect(subject).to include(revision1)
          expect(subject).not_to include(revision2)
        end
      end

      context 'when a label_selector is provided' do
        let(:message) { AppRevisionsListMessage.from_params({ 'label_selector' => 'key=value' }) }
        let!(:revision1label) { create(:revision_label_model, key_name: 'key', value: 'value', revision: revision1) }
        let!(:revision2label) { create(:revision_label_model, key_name: 'key2', value: 'value2', revision: revision2) }

        it 'returns the correct set of revisions' do
          results = fetcher.fetch(app, message).all
          expect(results).to contain_exactly(revision1)
        end
      end
    end

    describe '#fetch_deployed' do
      let!(:revision3) { create(:revision_model, version: 35, app: app) }

      let!(:process1) { create(:process, app: app, revision: revision1, type: 'web', state: 'STARTED') }
      let!(:process2) { create(:process, app: app, revision: revision2, type: 'web', state: 'STOPPED') }

      subject { fetcher.fetch_deployed(app) }

      it 'fetches all the deployed revisions' do
        expect(subject).to contain_exactly(revision1)
      end

      it 'handles processes with no revisions' do
        create(:process, app: app, type: 'web', state: 'STARTED')
        expect(subject).to contain_exactly(revision1)
      end
    end
  end
end
