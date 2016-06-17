require 'spec_helper'
require 'queries/log_access_fetcher'

module VCAP::CloudController
  RSpec.describe LogAccessFetcher do
    let(:space) { Space.make }
    let(:app) { AppModel.make(space_guid: space.guid) }
    let(:sad_app) { AppModel.make }
    let(:org) { space.organization }
    let(:fetcher) { described_class.new }
    let(:space_guids) { [space.guid] }

    describe '#app_exists?' do
      context 'for a v3 app guid' do
        let(:app_model) { AppModel.make }

        it 'returns true' do
          expect(fetcher.app_exists?(app_model.guid)).to eq(true)
        end
      end

      context 'for a v2 app guid' do
        let(:app_v2) { App.make }

        it 'returns true' do
          expect(fetcher.app_exists?(app_v2.guid)).to eq(true)
        end
      end

      it 'returns false if the guid cannot be found' do
        expect(fetcher.app_exists?('garbage_guid!')).to eq(false)
      end
    end

    describe '#app_exists_by_space?' do
      context 'when the user has access' do
        context 'to the v3 app guid' do
          it 'returns true' do
            expect(fetcher.app_exists_by_space?(app.guid, space_guids)).to eq(true)
          end
        end

        context 'to the v2 app guid' do
          let(:app) { App.make(space_guid: space.guid) }
          it 'returns true' do
            expect(fetcher.app_exists_by_space?(app.guid, space_guids)).to eq(true)
          end
        end
      end

      it 'returns false if the user does not have access to the app' do
        expect(fetcher.app_exists_by_space?(sad_app.guid, space_guids)).to eq(false)
      end

      it 'returns false if the guid cannot be found' do
        expect(fetcher.app_exists_by_space?('garbage_guid!', space_guids)).to eq(false)
      end
    end
  end
end
