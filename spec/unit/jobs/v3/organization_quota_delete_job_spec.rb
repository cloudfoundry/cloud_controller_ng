require 'spec_helper'
require 'jobs/v3/organization_quota_delete_job'
require 'actions/organization_quota_delete'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe OrganizationQuotaDeleteJob, job_context: :api do
      let!(:org_quota) { QuotaDefinition.make }

      subject(:job) do
        OrganizationQuotaDeleteJob.new(org_quota.guid)
      end

      describe '#resource_type' do
        it 'uses organization_quota as the resource type instead of the table name' do
          expect(job.resource_type).to eq('organization_quota')
        end
      end

      describe '#perform' do
        let!(:delete_action) { instance_double(VCAP::CloudController::OrganizationQuotaDeleteAction) }

        it 'runs the delete action on the quota' do
          expect(VCAP::CloudController::OrganizationQuotaDeleteAction).to receive(:new).and_return(delete_action)
          expect(delete_action).to receive(:delete).with(QuotaDefinition.where(guid: org_quota.guid)).and_return([])

          job.perform
        end
      end
    end
  end
end
