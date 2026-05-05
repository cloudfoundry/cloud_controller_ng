require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add parent_guid column to jobs table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260422120000_add_parent_guid_to_jobs.rb' }
  end

  describe 'jobs table' do
    it 'adds column and index, and handles idempotency gracefully' do
      expect(db[:jobs].columns).not_to include(:parent_guid)
      expect(db.indexes(:jobs)).not_to include(:jobs_parent_guid_index)

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:jobs].columns).to include(:parent_guid)
      expect(db.indexes(:jobs)).to include(:jobs_parent_guid_index)

      # Idempotency: running again does not raise
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:jobs].columns).to include(:parent_guid)
      expect(db.indexes(:jobs)).to include(:jobs_parent_guid_index)

      # Down migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:jobs].columns).not_to include(:parent_guid)
      expect(db.indexes(:jobs)).not_to include(:jobs_parent_guid_index)

      # Down idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:jobs].columns).not_to include(:parent_guid)
    end
  end
end
