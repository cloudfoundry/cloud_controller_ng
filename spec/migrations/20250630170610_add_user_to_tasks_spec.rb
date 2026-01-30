require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add user column to tasks table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250630170610_add_user_to_tasks.rb' }
  end

  describe 'tasks table' do
    it 'adds and removes user column with idempotency' do
      # Verify initial state
      expect(db[:tasks].columns).not_to include(:user)

      # === UP MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:tasks].columns).to include(:user)

      # Test up migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:tasks].columns).to include(:user)

      # === DOWN MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:tasks].columns).not_to include(:user)

      # Test down migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:tasks].columns).not_to include(:user)
    end
  end
end
