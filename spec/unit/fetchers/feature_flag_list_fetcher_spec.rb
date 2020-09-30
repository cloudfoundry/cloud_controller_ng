require 'spec_helper'

module VCAP::CloudController
  RSpec.describe FeatureFlagListFetcher do
    subject(:fetcher) { FeatureFlagListFetcher }
    let(:message) { FeatureFlagsListMessage.from_params(filters) }
    describe '#fetch_all' do
      let(:filters) { {} }

      before do
        VCAP::CloudController::FeatureFlag.plugin :timestamps, update_on_create: false
      end

      let!(:resource_1) { VCAP::CloudController::FeatureFlag.make(name: 'set_roles_by_username', updated_at: '2020-05-26T18:47:01Z') }
      let!(:resource_2) { VCAP::CloudController::FeatureFlag.make(name: 'task_creation', updated_at: '2020-05-26T18:47:02Z') }
      let!(:resource_3) { VCAP::CloudController::FeatureFlag.make(name: 'user_org_creation', updated_at: '2020-05-26T18:47:03Z') }
      let!(:resource_4) { VCAP::CloudController::FeatureFlag.make(name: 'unset_roles_by_username', updated_at: '2020-05-26T18:47:04Z') }

      after do
        VCAP::CloudController::FeatureFlag.plugin :timestamps, update_on_create: true
      end

      context 'when not filtering' do
        it 'returns an array of all FeatureFlags' do
          flag_names = VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS.keys.sort.map(&:to_s)
          expect(subject.fetch_all(message).map(&:name)).to contain_exactly(*flag_names)
        end
      end

      context 'when filtering on updated_ats' do
        let(:filters) {
          { updated_ats: { gt: '2020-05-26T18:47:02Z' } }
        }
        it 'it only returns records that have been updated in the time range' do
          expect(subject.fetch_all(message).map(&:name)).to contain_exactly('unset_roles_by_username', 'user_org_creation')
        end
      end
    end
  end
end
