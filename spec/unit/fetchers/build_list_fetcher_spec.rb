require 'spec_helper'
require 'messages/builds_list_message'
require 'fetchers/build_list_fetcher'

module VCAP::CloudController
  RSpec.describe BuildListFetcher do
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

    let(:package_for_app_1) { create(:package_model, app: app_in_space1) }
    let(:package2_in_space_1) { create(:package_model, app: app_in_space1) }

    let!(:staged_build_for_app1_space1) { create(:build_model, app: app_in_space1, package: package_for_app_1, state: BuildModel::STAGED_STATE) }
    let!(:failed_build_for_app1_space1) { create(:build_model, app: app_in_space1, package: package2_in_space_1, state: BuildModel::FAILED_STATE) }

    let!(:staged_build_for_app2_space1) { create(:build_model, app: app2_in_space1, state: BuildModel::STAGED_STATE) }

    let!(:staging_build_for_app3_space2) { create(:build_model, app: app3_in_space2, state: BuildModel::STAGING_STATE) }
    let!(:staging_build_for_app4_space3) { create(:build_model, app: app4_in_space3, state: BuildModel::STAGING_STATE) }

    subject(:fetcher) { BuildListFetcher }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { BuildsListMessage.from_params(filters) }
    let(:filters) { {} }

    let!(:lifecycle_data_for_app) do
      create(:buildpack_lifecycle_data_model,
             build: staging_build_for_app3_space2,
             buildpacks: [create(:buildpack).name])
    end

    describe '#fetch_all' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all(message)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns all of the builds' do
        results = fetcher.fetch_all(message)
        expect(results).to contain_exactly(staged_build_for_app1_space1, failed_build_for_app1_space1, staged_build_for_app2_space1, staging_build_for_app3_space2,
                                           staging_build_for_app4_space3)
      end

      context 'filtering app guids' do
        let(:filters) { { app_guids: [app_in_space1.guid] } }

        it 'returns all of the builds with the requested app guids' do
          results = fetcher.fetch_all(message).all
          expect(results).to contain_exactly(staged_build_for_app1_space1, failed_build_for_app1_space1)
        end
      end

      context 'filtering package guids' do
        let(:filters) { { package_guids: [package_for_app_1.guid] } }

        it 'returns all of the builds with the requested package guids' do
          results = fetcher.fetch_all(message).all
          expect(results).to contain_exactly(staged_build_for_app1_space1)
        end
      end

      context 'filtering states' do
        let(:filters) { { states: [BuildModel::STAGED_STATE, BuildModel::FAILED_STATE] } }
        let!(:failed_build_for_other_app) { create(:build_model, state: BuildModel::FAILED_STATE) }

        it 'returns all of the builds with the requested states' do
          results = fetcher.fetch_all(message).all
          expect(results).to contain_exactly(staged_build_for_app1_space1, failed_build_for_app1_space1, staged_build_for_app2_space1, failed_build_for_other_app)
        end
      end

      describe 'eager loading associated resources' do
        it 'eager loads the specified resources for all builds' do
          results = fetcher.fetch_all(
            message,
            eager_loaded_associations: [
              :labels,
              :annotations,
              { buildpack_lifecycle_data: :buildpack_lifecycle_buildpacks }
            ]
          ).where(id: staging_build_for_app3_space2.id).all
          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be true
          expect(results.first.associations.key?(:buildpack_lifecycle_data)).to be true
          expect(results.first.buildpack_lifecycle_data.associations.key?(:buildpack_lifecycle_buildpacks)).to be true
        end
      end
    end

    describe '#fetch_for_spaces' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns only the builds in spaces requested' do
        results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
        expect(results.all).to contain_exactly(staged_build_for_app1_space1, failed_build_for_app1_space1, staged_build_for_app2_space1, staging_build_for_app4_space3)
      end

      describe 'eager loading associated resources' do
        it 'eager loads the specified resources for all builds' do
          results = fetcher.fetch_for_spaces(
            message,
            space_guids: [space2.guid],
            eager_loaded_associations: [
              :labels,
              { buildpack_lifecycle_data: :buildpack_lifecycle_buildpacks }
            ]
          ).where(id: staging_build_for_app3_space2.id).all

          expect(results.first.buildpack_lifecycle_data.associations.key?(:buildpack_lifecycle_buildpacks)).to be true
          expect(results.first.associations.key?(:buildpack_lifecycle_data)).to be true
          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be false
        end
      end

      describe 'filtering on messages' do
        context 'filtering states' do
          context 'when staged or failed' do
            let(:filters) { { states: [BuildModel::STAGED_STATE, BuildModel::FAILED_STATE] } }

            it 'returns all of the builds with the requested states' do
              results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
              expect(results.all).to contain_exactly(staged_build_for_app1_space1, failed_build_for_app1_space1, staged_build_for_app2_space1)
            end
          end

          context 'when staging or failed' do
            let(:filters) { { states: [BuildModel::STAGING_STATE, BuildModel::FAILED_STATE] } }

            it 'returns all of the builds with the requested states' do
              results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
              expect(results.all).to contain_exactly(failed_build_for_app1_space1, staging_build_for_app4_space3)
            end
          end
        end

        context 'filtering app guids' do
          let(:filters) { { app_guids: [app_in_space1.guid] } }

          it 'returns all the builds associated with the requested app guid' do
            results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
            expect(results.all).to contain_exactly(staged_build_for_app1_space1, failed_build_for_app1_space1)
          end
        end

        context 'filtering package guids' do
          let(:filters) { { package_guids: [package_for_app_1.guid, package2_in_space_1.guid] } }

          it 'returns all the builds associated with the requested package guid' do
            results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
            expect(results.all).to contain_exactly(staged_build_for_app1_space1, failed_build_for_app1_space1)
          end
        end

        context 'when using multiple filters' do
          let(:filters) { { package_guids: [package_for_app_1.guid, package2_in_space_1.guid], states: BuildModel::STAGED_STATE } }

          it 'returns all the STAGED builds associated with the requested package guids' do
            results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
            expect(results.all).to contain_exactly(staged_build_for_app1_space1)
          end
        end
      end
    end
  end
end
