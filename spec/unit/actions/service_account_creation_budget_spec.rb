require 'spec_helper'
require 'actions/service_account_creation_budget'

module VCAP::CloudController
  RSpec.describe ServiceAccountCreationBudget do
    it 'serializes concurrent creations by the same principal across spaces', isolation: :truncation do
      TestConfig.override(service_account_creation_limit: 1)
      principal = create(:user)
      spaces = create_list(:space, 2)
      gate = Queue.new
      snapshots = Queue.new
      consume_budget = Queue.new
      threads = spaces.each_with_index.map do |space, index|
        Thread.new do
          gate.pop
          ServiceAccountModel.db.transaction do
            authenticated_principal = User.first(guid: principal.guid)
            snapshots << true
            consume_budget.pop
            described_class.consume(authenticated_principal, exempt: false) do
              ServiceAccountModel.create(name: "worker-#{index}", space: space)
            end
          end
          :created
        rescue CloudController::Errors::V3::ApiError => e
          e.name
        end
      end
      threads.size.times { gate << true }
      Timeout.timeout(10) { threads.size.times { snapshots.pop } }
      threads.size.times { consume_budget << true }

      expect(threads.map(&:value)).to contain_exactly(:created, 'ServiceAccountCreationLimitExceeded')
      expect(ServiceAccountModel.count).to eq(1)
      expect(ServiceAccountModel.db[:service_account_creations].count).to eq(1)
      expect(ServiceAccountModel.db[:service_account_names].count).to eq(1)
    end
  end
end
