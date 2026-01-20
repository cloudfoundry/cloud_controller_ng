require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add user column to processes table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250610212414_add_user_to_processes.rb' }
  end

  describe 'processes table' do
    it 'adds a column `user` and handles idempotency' do
      expect(db[:processes].columns).not_to include(:user)
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:processes].columns).to include(:user)

      # Test idempotency: running again when column exists should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
    end

    describe 'idempotency of down' do
      it 'removes column and handles idempotency' do
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
        expect(db[:processes].columns).to include(:user)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db[:processes].columns).not_to include(:user)

        # Test idempotency: running rollback again when column doesn't exist should not fail
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      end
    end
  end
end
