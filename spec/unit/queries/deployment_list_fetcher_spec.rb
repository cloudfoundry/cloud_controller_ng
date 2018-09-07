require 'spec_helper'
require 'messages/deployments_list_message'
require 'fetchers/deployment_list_fetcher'

module VCAP::CloudController
  RSpec.describe DeploymentListFetcher do
    let(:space1) { Space.make }
    let(:space2) { Space.make }
    let(:space3) { Space.make }
    let(:org_1_guid) { space1.organization.guid }
    let(:org_2_guid) { space2.organization.guid }
    let(:org_3_guid) { space3.organization.guid }
    let(:app_in_space1) { AppModel.make(space_guid: space1.guid, guid: 'app1') }
    let(:app2_in_space1) { AppModel.make(space_guid: space1.guid, guid: 'app2') }
    let(:app3_in_space2) { AppModel.make(space_guid: space2.guid, guid: 'app3') }
    let(:app4_in_space3) { AppModel.make(space_guid: space3.guid, guid: 'app4') }

    let!(:deployment_for_app1_space1) { DeploymentModel.make(app_guid: app_in_space1.guid, state: 'DEPLOYED') }
    let!(:deployment_for_app2_space1) { DeploymentModel.make(app_guid: app2_in_space1.guid, state: 'CANCELING') }
    let!(:deployment_for_app3_space2) { DeploymentModel.make(app_guid: app3_in_space2.guid, state: 'CANCELED') }
    let!(:deployment_for_app4_space3) { DeploymentModel.make(app_guid: app4_in_space3.guid, state: 'DEPLOYING') }

    subject(:fetcher) { DeploymentListFetcher.new(message: message) }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { DeploymentsListMessage.new(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns all of the deployments' do
        results = fetcher.fetch_all
        expect(results).to match_array([deployment_for_app1_space1,
                                        deployment_for_app2_space1, deployment_for_app3_space2, deployment_for_app4_space3])
      end

      context 'filtering app guids' do
        let(:filters) { { app_guids: [app_in_space1.guid, app3_in_space2.guid] } }

        it 'returns all of the deployments with the requested app guids' do
          results = fetcher.fetch_all.all
          expect(results).to match_array([deployment_for_app1_space1, deployment_for_app3_space2])
        end
      end

      context 'filtering states' do
        let(:filters) { { states: %w/DEPLOYED CANCELED/ } }

        it 'returns all of the deployments with the requested states' do
          results = fetcher.fetch_all.all
          expect(results).to match_array([deployment_for_app1_space1, deployment_for_app3_space2])
        end
      end
    end

    describe '#fetch_for_spaces' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_for_spaces(space_guids: [space1.guid, space3.guid])
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns only the deployments in spaces requested' do
        results = fetcher.fetch_for_spaces(space_guids: [space1.guid, space3.guid])
        expect(results.all).to match_array([
          deployment_for_app1_space1,
          deployment_for_app2_space1,
          deployment_for_app4_space3
        ])
      end

      describe 'filtering on app guids' do
        let(:filters) { { app_guids: [app_in_space1.guid, app4_in_space3.guid] } }

        it 'returns all the deployments associated with the requested app guid' do
          results = fetcher.fetch_for_spaces(space_guids: [space1.guid, space3.guid])
          expect(results.all).to match_array([deployment_for_app1_space1, deployment_for_app4_space3])
        end
      end

      describe 'filtering on states' do
        let(:filters) { { states: %w/DEPLOYED CANCELED/ } }

        it 'returns all the deployments associated with the requested states' do
          results = fetcher.fetch_for_spaces(space_guids: [space1.guid, space3.guid])
          expect(results.all).to match_array([deployment_for_app1_space1])
        end
      end
    end
  end
end
