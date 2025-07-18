require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add user column to tasks table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250630170610_add_user_to_tasks.rb' }
  end

  describe 'tasks table' do
    it 'adds a column `user`' do
      expect(db[:tasks].columns).not_to include(:user)
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:tasks].columns).to include(:user)
    end

    describe 'idempotency of up' do
      context '`user` column already exists' do
        before do
          db.add_column :tasks, :user, String, size: 255, if_not_exists: true
        end

        it 'does not fail' do
          expect(db[:tasks].columns).to include(:user)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        end
      end
    end

    describe 'idempotency of down' do
      context 'user column exists' do
        before do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
        end

        it 'continues to remove the `user_guid` column' do
          expect(db[:tasks].columns).to include(:user)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
          expect(db[:tasks].columns).not_to include(:user)
        end
      end

      context 'column does not exist' do
        before do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
          db.drop_column :tasks, :user
        end

        it 'does not fail' do
          expect(db[:tasks].columns).not_to include(:user)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        end
      end
    end
  end
end
