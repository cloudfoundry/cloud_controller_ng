# rubocop:disable Migration/TooManyMigrationRuns
require 'migrations/helpers/migration_shared_context'
require 'database/bigint_migration'

RSpec.shared_context 'bigint migration step1' do
  before(:all) { skip unless Sequel::Model.db.database_type == :postgres } # rubocop:disable RSpec/BeforeAfterAll

  include_context 'migration'

  let(:skip_bigint_id_migration) { nil }
  let(:logger) { double(:logger, info: nil) }

  before do
    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_bigint_id_migration).and_return(skip_bigint_id_migration)
    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:migration_psql_concurrent_statement_timeout_in_seconds).and_return(300)
    allow(Steno).to receive(:logger).and_return(logger)
  end

  describe 'up' do
    context 'when skip_bigint_id_migration is false' do
      let(:skip_bigint_id_migration) { false }

      it 'when table is empty: changes id to bigint, no id_bigint column; backfill raises error' do
        db[table].delete

        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).not_to have_table_with_column(table, :id_bigint)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

        expect(db).to have_table_with_column_and_type(table, :id, 'bigint')
        expect(db).not_to have_table_with_column(table, :id_bigint)

        expect do
          VCAP::BigintMigration.backfill(logger, db, table)
        end.to raise_error(RuntimeError, /table '#{table}' does not contain column 'id_bigint'/)
      end

      it 'when table is not empty: keeps id as integer, adds id_bigint column with trigger; backfill works correctly' do
        old_id = insert.call(db)
        100.times { insert.call(db) }

        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).not_to have_table_with_column(table, :id_bigint)
        expect(db).not_to have_trigger_function_for_table(table)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).to have_table_with_column_and_type(table, :id_bigint, 'bigint')
        expect(db).to have_trigger_function_for_table(table)

        # Existing entry should not have id_bigint populated; new entries should
        expect(db[table].where(id: old_id).get(:id_bigint)).to be_nil
        new_id = insert.call(db)
        expect(db[table].where(id: new_id).get(:id_bigint)).to eq(new_id)

        # Default batch size: backfills all entries in a single update
        expect(db).to have_table_with_unpopulated_column(table, :id_bigint)
        expect do
          VCAP::BigintMigration.backfill(logger, db, table)
        end.to have_queried_db_times(/update/i, 1)
        expect(db).not_to have_table_with_unpopulated_column(table, :id_bigint)

        # Re-insert rows for subsequent backfill batch-size tests
        db[table].delete
        insert.call(db)
        100.times { insert.call(db) }
        # Trigger already set; id_bigint populated for new rows; re-create unpopulated state via direct update
        db[table].update(id_bigint: nil)

        # Custom batch size (30): needs 4 updates for 101 rows
        expect(db).to have_table_with_unpopulated_column(table, :id_bigint)
        expect do
          VCAP::BigintMigration.backfill(logger, db, table, batch_size: 30)
        end.to have_queried_db_times(/update/i, 4)
        expect(db).not_to have_table_with_unpopulated_column(table, :id_bigint)

        db[table].update(id_bigint: nil)

        # Limited iterations (2): stops early, leaving some rows unpopulated
        expect(db).to have_table_with_unpopulated_column(table, :id_bigint)
        expect do
          VCAP::BigintMigration.backfill(logger, db, table, batch_size: 30, iterations: 2)
        end.to have_queried_db_times(/update/i, 2)
        expect(db).to have_table_with_unpopulated_column(table, :id_bigint)

        db[table].delete
      end
    end

    context 'when skip_bigint_id_migration is true' do
      let(:skip_bigint_id_migration) { true }

      it "neither changes the id column's type, nor adds the id_bigint column" do
        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).not_to have_table_with_column(table, :id_bigint)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).not_to have_table_with_column(table, :id_bigint)
      end
    end
  end

  describe 'down' do
    it 'when table is empty: reverts id column type to integer' do
      db[table].delete
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

      expect(db).to have_table_with_column_and_type(table, :id, 'bigint')

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error

      expect(db).to have_table_with_column_and_type(table, :id, 'integer')
    end

    it 'when table is not empty: drops id_bigint column and trigger function' do
      insert.call(db)
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

      expect(db).to have_table_with_column(table, :id_bigint)
      expect(db).to have_trigger_function_for_table(table)

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error

      expect(db).not_to have_table_with_column(table, :id_bigint)
      expect(db).not_to have_trigger_function_for_table(table)

      db[table].delete
    end
  end
end
# rubocop:enable Migration/TooManyMigrationRuns
