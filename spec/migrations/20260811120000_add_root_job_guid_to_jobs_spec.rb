require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add root_job_guid column to jobs table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260811120000_add_root_job_guid_to_jobs.rb' }
  end

  describe 'jobs table' do
    it 'adds column and index, and handles idempotency gracefully' do
      expect(db[:jobs].columns).not_to include(:root_job_guid)
      expect(db.indexes(:jobs)).not_to be_key(:jobs_root_job_guid_index)
      expect { run_migration }.not_to raise_error
      expect(db[:jobs].columns).to include(:root_job_guid)
      expect(db.indexes(:jobs)).to be_key(:jobs_root_job_guid_index)

      test_up_migration_idempotency
      expect(db[:jobs].columns).to include(:root_job_guid)
      expect(db.indexes(:jobs)).to be_key(:jobs_root_job_guid_index)

      expect { revert_migration }.not_to raise_error
      expect(db[:jobs].columns).not_to include(:root_job_guid)
      expect(db.indexes(:jobs)).not_to be_key(:jobs_root_job_guid_index)

      test_down_migration_idempotency
      expect(db[:jobs].columns).not_to include(:root_job_guid)
      expect(db.indexes(:jobs)).not_to be_key(:jobs_root_job_guid_index)
    end
  end
end
