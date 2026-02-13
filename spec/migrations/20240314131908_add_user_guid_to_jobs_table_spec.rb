require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add user_guid column to jobs table and add an index for that column', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240314131908_add_user_guid_to_jobs_table.rb' }
  end

  describe 'jobs table' do
    it 'adds column and index, and handles idempotency gracefully' do
      # Test basic up migration
      expect(db[:jobs].columns).not_to include(:user_guid)
      expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:jobs].columns).to include(:user_guid)
      expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)

      # Test up migration again (both column and index already exist - idempotency)
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:jobs].columns).to include(:user_guid)
      expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)

      # Test down migration with pre-dropped index
      db.drop_index :jobs, :user_guid, name: :jobs_user_guid_index
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:jobs].columns).not_to include(:user_guid)
      expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)

      # Test down migration when both already removed (idempotency)
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:jobs].columns).not_to include(:user_guid)
      expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
    end
  end
end
