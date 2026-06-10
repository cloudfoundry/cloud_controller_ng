require 'spec_helper'
require 'messages/builds_list_message'
require 'fetchers/app_builds_list_fetcher'

module VCAP::CloudController
  RSpec.describe AppBuildsListFetcher do
    let(:subject) { AppBuildsListFetcher.fetch_all(app_guid, message) }
    let(:space1) { create(:space) }
    let(:space2) { create(:space) }
    let(:space3) { create(:space) }
    let(:org_1_guid) { space1.organization.guid }
    let(:org_2_guid) { space2.organization.guid }
    let(:org_3_guid) { space3.organization.guid }
    let(:app_in_space1) { create(:app_model, space: space1, guid: 'app1') }
    let(:app2_in_space1) { create(:app_model, space: space1, guid: 'app2') }
    let(:app3_in_space2) { create(:app_model, space: space2, guid: 'app3') }
    let(:app4_in_space3) { create(:app_model, space: space3, guid: 'app4') }

    let!(:staged_build_for_app1_space1) { create(:build_model, app: app_in_space1, state: BuildModel::STAGED_STATE) }
    let!(:failed_build_for_app1_space1) { create(:build_model, app: app_in_space1, state: BuildModel::FAILED_STATE) }

    let!(:staged_build_for_app2_space1) { create(:build_model, app: app2_in_space1, state: BuildModel::STAGED_STATE) }

    let!(:staging_build_for_app3_space2) { create(:build_model, app: app3_in_space2, state: BuildModel::STAGING_STATE) }
    let!(:staging_build_for_app4_space3) { create(:build_model, app: app4_in_space3, state: BuildModel::STAGING_STATE) }

    # let(:fetcher) { AppBuildsListFetcher.new(app_guid, message) }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { AppBuildsListMessage.from_params(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      let(:app_guid) { app_in_space1.guid }

      context 'when looking at app_in_space1' do
        it 'returns a Sequel::Dataset' do
          expect(subject).to be_a(Sequel::Dataset)
        end

        it 'returns all of the builds' do
          expect(subject.count).to eq(2)
          expect(subject.all).to contain_exactly(staged_build_for_app1_space1, failed_build_for_app1_space1)
        end

        context 'filtering states' do
          let(:filters) { { states: [BuildModel::STAGED_STATE] } }

          it 'returns all of the builds with the requested states' do
            expect(subject.all).to contain_exactly(staged_build_for_app1_space1)
          end
        end
      end
    end
  end
end
