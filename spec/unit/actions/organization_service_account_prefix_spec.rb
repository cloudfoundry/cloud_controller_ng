require 'spec_helper'
require 'actions/organization_create'
require 'actions/organization_update'

module VCAP::CloudController
  RSpec.describe 'Atomic organization service account prefix allocation' do
    let(:user_audit_info) { UserAuditInfo.new(user_guid: create(:user).guid, user_email: 'admin@example.com') }

    it 'allows exactly one concurrent creator to reserve a prefix', isolation: :truncation do
      audit_info = user_audit_info
      gate = Queue.new
      threads = 2.times.map do |index|
        Thread.new do
          gate.pop
          message = OrganizationCreateMessage.new(name: "org-#{index}", service_account_prefix: 'shared-prefix')
          OrganizationCreate.new(user_audit_info: audit_info).create(message)
          :created
        rescue OrganizationCreate::Error => e
          e.message
        end
      end
      threads.size.times { gate << true }

      expect(threads.map(&:value)).to contain_exactly(:created, "Service account prefix 'shared-prefix' is already reserved.")
      expect(Organization.where(name: %w[org-0 org-1]).count).to eq(1)
    end

    it 'serializes competing allocations on the same initially unset org', isolation: :truncation do
      org = create(:organization)
      audit_info = user_audit_info
      gate = Queue.new
      threads = %w[first-prefix second-prefix].map do |prefix|
        Thread.new do
          stale_org = Organization.first(guid: org.guid)
          gate.pop
          OrganizationUpdate.new(audit_info).update(stale_org, OrganizationUpdateMessage.new(service_account_prefix: prefix))
          :updated
        rescue OrganizationUpdate::Error => e
          e.message
        end
      end
      threads.size.times { gate << true }

      expect(threads.map(&:value)).to contain_exactly(:updated, 'Service account prefix is immutable once allocated.')
    end
  end
end
