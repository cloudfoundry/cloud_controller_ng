require 'spec_helper'
require 'actions/space_quota_delete'

module VCAP::CloudController
  RSpec.describe SpaceQuotaDeleteAction do
    subject(:space_quota_delete) { SpaceQuotaDeleteAction.new }

    describe '#delete' do
      let!(:quota) { SpaceQuotaDefinition.make }

      it 'deletes the space quota' do
        expect {
          space_quota_delete.delete([quota])
        }.to change { SpaceQuotaDefinition.count }.by(-1)

        expect { quota.refresh }.to raise_error Sequel::Error, 'Record not found'
      end
    end
  end
end
