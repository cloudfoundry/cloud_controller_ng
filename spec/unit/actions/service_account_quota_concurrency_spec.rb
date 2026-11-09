require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Service account quota concurrency' do
    it 'serializes direct account creations within an org', isolation: :truncation do
      org = create(:organization, service_account_prefix: 'race-team')
      org.quota_definition.update(total_service_accounts: 1)
      space = create(:space, organization: org)
      gate = Queue.new
      threads = 2.times.map do |index|
        Thread.new do
          gate.pop
          ServiceAccountModel.create(name: "worker-#{index}", space: Space.first(guid: space.guid))
          :created
        rescue Sequel::ValidationFailed
          :quota_exceeded
        end
      end
      threads.size.times { gate << true }
      expect(threads.map(&:value)).to contain_exactly(:created, :quota_exceeded)
      expect(ServiceAccountModel.where(organization_id: org.id).count).to eq(1)
    end
  end
end
