require 'spec_helper'
require 'actions/organization_quota_delete'

module VCAP::CloudController
  RSpec.describe OrganizationQuotaDeleteAction do
    subject(:org_quota_delete) { OrganizationQuotaDeleteAction.new }

    describe '#delete' do
      let!(:quota) { QuotaDefinition.make }
      it 'deletes the organization quota' do
        expect {
          org_quota_delete.delete([quota])
        }.to change { QuotaDefinition.count }.by(-1)

        expect { quota.refresh }.to raise_error Sequel::Error, 'Record not found'
      end
    end
  end
end
