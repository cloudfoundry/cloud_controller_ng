require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add an index for task_guid on app_usage_events table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240529195136_add_task_guid_index_to_app_usage_events.rb' }
  end

  describe 'app_usage_events table' do
    describe 'up migration' do
      context 'index does not exist' do
        it 'adds an index on the task_guid column' do
          expect(db.indexes(:app_usage_events)).not_to include(:app_usage_events_task_guid_index)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(:app_usage_events)).to include(:app_usage_events_task_guid_index)
        end
      end

      context 'index already exists' do
        before do
          db.add_index :app_usage_events, :task_guid, name: :app_usage_events_task_guid_index
        end

        it 'does not fail' do
          expect(db.indexes(:app_usage_events)).to include(:app_usage_events_task_guid_index)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(:app_usage_events)).to include(:app_usage_events_task_guid_index)
        end
      end
    end

    describe 'down migration' do
      context 'index does not exist' do
        before do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
          db.drop_index :app_usage_events, :task_guid, name: :app_usage_events_task_guid_index
        end

        it 'does not fail' do
          expect(db.indexes(:app_usage_events)).not_to include(:app_usage_events_task_guid_index)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(:app_usage_events)).not_to include(:app_usage_events_task_guid_index)
        end
      end

      context 'index does exist' do
        before do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
        end

        it 'removes the index' do
          expect(db.indexes(:app_usage_events)).to include(:app_usage_events_task_guid_index)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(:app_usage_events)).not_to include(:app_usage_events_task_guid_index)
        end
      end
    end
  end
end
