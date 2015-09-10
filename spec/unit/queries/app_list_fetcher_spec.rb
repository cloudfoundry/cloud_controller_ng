require 'spec_helper'

module VCAP::CloudController
  describe AppListFetcher do
    describe '#fetch' do
      let(:space) { Space.make }
      let(:app) { AppModel.make(space_guid: space.guid) }
      let(:sad_app) { AppModel.make(space_guid: space.guid) }
      let(:org) { space.organization }
      let(:fetcher) { described_class.new }
      let(:space_guids) { [space.guid] }
      let(:pagination_options) { PaginationOptions.new({}) }
      let(:facets) { {} }

      apps = nil

      before do
        app.save
        sad_app.save
        apps = fetcher.fetch(pagination_options, facets, space_guids)
      end

      after do
        apps = nil
      end

      it 'fetch_all includes all the apps' do
        app = AppModel.make
        expect(fetcher.fetch_all(pagination_options, {}).records).to include(app)
      end

      context 'when no facets are specified' do
        let(:facets) { {} }

        it 'returns all of the desired apps' do
          expect(apps.records).to include(app, sad_app)
        end
      end

      context 'when the app names are provided' do
        let(:facets) { { 'names' => [app.name] } }

        it 'returns all of the desired apps' do
          expect(apps.records).to include(app)
          expect(apps.records).to_not include(sad_app)
        end
      end

      context 'when the app space_guids are provided' do
        let(:facets) { { 'space_guids' => [space.guid] } }
        let(:sad_app) { AppModel.make }

        it 'returns all of the desired apps' do
          expect(apps.records).to include(app)
          expect(apps.records).to_not include(sad_app)
        end
      end

      context 'when the organization guids are provided' do
        let(:facets) { { 'organization_guids' => [org.guid] } }
        let(:sad_org) { Organization.make }
        let(:sad_space) { Space.make(organization_guid: sad_org.guid) }
        let(:sad_app) { AppModel.make(space_guid: sad_space.guid) }
        let(:space_guids) { [space.guid, sad_space.guid] }

        it 'returns all of the desired apps' do
          expect(apps.records).to include(app)
          expect(apps.records).to_not include(sad_app)
        end
      end

      context 'when the app guids are provided' do
        let(:facets) { { 'guids' => [app.guid] } }

        it 'returns all of the desired apps' do
          expect(apps.records).to include(app)
          expect(apps.records).to_not include(sad_app)
        end
      end
    end
  end
end
