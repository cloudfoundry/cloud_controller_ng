require 'spec_helper'
require 'messages/apps_list_message'

module VCAP::CloudController
  RSpec.describe AppListFetcher do
    describe '#fetch' do
      let(:space) { Space.make }
      let(:app) { AppModel.make(space_guid: space.guid) }
      let(:sad_app) { AppModel.make(space_guid: space.guid) }
      let(:org) { space.organization }
      let(:fetcher) { described_class.new }
      let(:space_guids) { [space.guid] }
      let(:pagination_options) { PaginationOptions.new({}) }
      let(:message) { AppsListMessage.new(filters) }
      let(:filters) { {} }

      apps = nil

      before do
        app.save
        sad_app.save
        apps = fetcher.fetch(message, space_guids)
      end

      after do
        apps = nil
      end

      it 'fetch_all includes all the apps' do
        app = AppModel.make
        expect(fetcher.fetch_all(message).all).to include(app)
      end

      context 'when no filters are specified' do
        it 'returns all of the desired apps' do
          expect(apps.all).to include(app, sad_app)
        end
      end

      context 'when the app names are provided' do
        let(:filters) { { names: [app.name] } }

        it 'returns all of the desired apps' do
          expect(apps.all).to include(app)
          expect(apps.all).to_not include(sad_app)
        end
      end

      context 'when the app space_guids are provided' do
        let(:filters) { { space_guids: [space.guid] } }
        let(:sad_app) { AppModel.make }

        it 'returns all of the desired apps' do
          expect(apps.all).to include(app)
          expect(apps.all).to_not include(sad_app)
        end
      end

      context 'when the organization guids are provided' do
        let(:filters) { { organization_guids: [org.guid] } }
        let(:sad_org) { Organization.make }
        let(:sad_space) { Space.make(organization_guid: sad_org.guid) }
        let(:sad_app) { AppModel.make(space_guid: sad_space.guid) }
        let(:space_guids) { [space.guid, sad_space.guid] }

        it 'returns all of the desired apps' do
          expect(apps.all).to include(app)
          expect(apps.all).to_not include(sad_app)
        end
      end

      context 'when the app guids are provided' do
        let(:filters) { { guids: [app.guid] } }

        it 'returns all of the desired apps' do
          expect(apps.all).to include(app)
          expect(apps.all).to_not include(sad_app)
        end
      end
    end
  end
end
