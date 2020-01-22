require 'spec_helper'
require 'actions/organization_quota_delete'

module VCAP::CloudController
  RSpec.describe OrganizationQuotaDeleteAction do
    let(:org_quota) { QuotaDefinition.make }

    describe '#delete' do
      it 'deletes the organization quota' do
        OrganizationQuotaDeleteAction.new.delete(org_quota)
        expect { org_quota.refresh }.to raise_error Sequel::Error, 'Record not found'
      end
    end
  end
end
