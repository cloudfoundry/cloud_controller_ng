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

    let!(:deployment_for_app1_space1) { DeploymentModel.make(guid: 'deployment_for_app1_space1',
      app_guid: app_in_space1.guid,
      state: VCAP::CloudController::DeploymentModel::DEPLOYED_STATE,
      status_value: VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
      status_reason: VCAP::CloudController::DeploymentModel::DEPLOYED_STATUS_REASON)
    }
    let!(:deployment_for_app1_space1_superseded) { DeploymentModel.make(guid: 'deployment_for_app1_space1_superseded',
      app_guid: app_in_space1.guid,
      state: VCAP::CloudController::DeploymentModel::DEPLOYED_STATE,
      status_value: VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
      status_reason: VCAP::CloudController::DeploymentModel::SUPERSEDED_STATUS_REASON)
    }
    let!(:deployment_for_app2_space1) { DeploymentModel.make(guid: 'deployment_for_app2_space1',
      app_guid: app2_in_space1.guid,
      state: VCAP::CloudController::DeploymentModel::CANCELING_STATE,
      status_value: VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
      status_reason: VCAP::CloudController::DeploymentModel::CANCELING_STATUS_REASON)
    }
    let!(:deployment_for_app3_space2) { DeploymentModel.make(guid: 'deployment_for_app3_space2',
      app_guid: app3_in_space2.guid,
      state: VCAP::CloudController::DeploymentModel::CANCELED_STATE,
      status_value: VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
      status_reason: VCAP::CloudController::DeploymentModel::CANCELED_STATUS_REASON)
    }
    let!(:deployment_for_app4_space3) { DeploymentModel.make(guid: 'deployment_for_app4_space3',
      app_guid: app4_in_space3.guid,
      state: VCAP::CloudController::DeploymentModel::DEPLOYING_STATE,
      status_value: VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
      status_reason: VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON)
    }

    subject(:fetcher) { DeploymentListFetcher }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { DeploymentsListMessage.from_params(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all(message)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns all of the deployments' do
        results = fetcher.fetch_all(message)
        expect(results).to match_array([deployment_for_app1_space1, deployment_for_app1_space1_superseded,
                                        deployment_for_app2_space1, deployment_for_app3_space2, deployment_for_app4_space3])
      end

      context 'filtering app guids' do
        let(:filters) { { app_guids: [app_in_space1.guid, app3_in_space2.guid] } }

        it 'returns all of the deployments with the requested app guids' do
          results = fetcher.fetch_all(message).all
          expect(results).to match_array([deployment_for_app1_space1, deployment_for_app1_space1_superseded, deployment_for_app3_space2])
        end
      end

      context 'filtering states' do
        let(:filters) { { states: %w/DEPLOYED CANCELED/ } }

        it 'returns all of the deployments with the requested states' do
          results = fetcher.fetch_all(message).all
          expect(results).to match_array([deployment_for_app1_space1, deployment_for_app1_space1_superseded, deployment_for_app3_space2])
        end
      end

      context 'filtering status reasons' do
        let(:filters) { { status_reasons: %w/DEPLOYED SUPERSEDED/ } }

        it 'returns all of the deployments with the requested states' do
          results = fetcher.fetch_all(message).all
          expect(results).to match_array([deployment_for_app1_space1, deployment_for_app1_space1_superseded])
        end
      end

      context 'filtering nil status reasons' do
        let(:filters) { { status_reasons: %w/DEPLOYING CANCELING/ } }

        it 'returns all of the deployments with the requested states' do
          results = fetcher.fetch_all(message).all
          expect(results).to match_array([deployment_for_app2_space1, deployment_for_app4_space3])
        end
      end

      context 'filtering a mix of nil and non-nil status reasons' do
        let(:filters) { { status_reasons: %w(CANCELED CANCELING DEPLOYING) } }

        it 'returns all of the deployments with the requested states' do
          results = fetcher.fetch_all(message).all
          expect(results).to match_array([deployment_for_app2_space1, deployment_for_app3_space2, deployment_for_app4_space3])
        end
      end

      context 'filtering status values' do
        let(:filters) { { status_values: %w/FINALIZED/ } }

        it 'returns all of the deployments with the requested states' do
          results = fetcher.fetch_all(message).all
          expect(results).to match_array([deployment_for_app1_space1, deployment_for_app1_space1_superseded, deployment_for_app3_space2])
        end
      end

      context 'filtering label_selector' do
        let(:message) { DeploymentsListMessage.from_params({ 'label_selector' => 'key=value' }) }
        let!(:deployment1label) { DeploymentLabelModel.make(key_name: 'key', value: 'value', deployment: deployment_for_app1_space1) }
        let!(:deployment2label) { DeploymentLabelModel.make(key_name: 'key2', value: 'value2', deployment: deployment_for_app2_space1) }

        it 'returns the correct set of deployments' do
          results = fetcher.fetch_all(message).all
          expect(results).to contain_exactly(deployment_for_app1_space1)
        end
      end
    end

    describe '#fetch_for_spaces' do
      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns only the deployments in spaces requested' do
        results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
        expect(results.all).to match_array([
          deployment_for_app1_space1,
          deployment_for_app1_space1_superseded,
          deployment_for_app2_space1,
          deployment_for_app4_space3
        ])
      end

      describe 'filtering on app guids' do
        let(:filters) { { app_guids: [app_in_space1.guid, app4_in_space3.guid] } }

        it 'returns all the deployments associated with the requested app guid' do
          results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
          expect(results.all).to match_array([deployment_for_app1_space1, deployment_for_app1_space1_superseded, deployment_for_app4_space3])
        end
      end

      describe 'filtering on states' do
        let(:filters) { { states: %w/DEPLOYED CANCELED/ } }

        it 'returns all the deployments associated with the requested states' do
          results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
          expect(results.all).to match_array([deployment_for_app1_space1, deployment_for_app1_space1_superseded])
        end
      end

      describe 'filtering label_selector' do
        let(:message) { DeploymentsListMessage.from_params({ 'label_selector' => 'key=value' }) }
        let!(:deployment1label) { DeploymentLabelModel.make(key_name: 'key', value: 'value', deployment: deployment_for_app1_space1) }
        let!(:deployment2label) { DeploymentLabelModel.make(key_name: 'key', value: 'value', deployment: deployment_for_app3_space2) }
        let!(:deployment2label) { DeploymentLabelModel.make(key_name: 'key2', value: 'value2', deployment: deployment_for_app4_space3) }

        it 'returns the correct set of deployments' do
          results = fetcher.fetch_for_spaces(message, space_guids: [space1.guid, space3.guid])
          expect(results).to contain_exactly(deployment_for_app1_space1)
        end
      end
    end
  end
end
