require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe "migration to remove foreign key constraint on table 'job_warnings' and column 'fk_jobs_id'", isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250116144231_remove_unnecessary_fk_in_job_warnings.rb' }
  end

  describe 'job_warnings table' do
    it 'removes the fk constraint and column, handles idempotency' do
      # Run migration
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

      expect(db.foreign_key_list(:job_warnings)).to be_empty
      expect(db[:job_warnings].columns).not_to include(:fk_jobs_id)

      # Test idempotency: running again when constraint doesn't exist should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
    end
  end
end
