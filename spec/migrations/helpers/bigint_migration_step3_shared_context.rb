# rubocop:disable Migration/TooManyMigrationRuns
require 'migrations/helpers/migration_shared_context'
require 'database/bigint_migration'

RSpec.shared_context 'bigint migration step3a' do
  before(:all) { skip unless Sequel::Model.db.database_type == :postgres } # rubocop:disable RSpec/BeforeAfterAll

  let(:migration_filename) { migration_filename_step1 }
  let(:current_migration_index_step3a) { migration_filename_step3a.match(/\A\d+/)[0].to_i }

  include_context 'migration'

  let(:skip_bigint_id_migration) { false }
  let(:logger) { double(:logger, info: nil) }

  before do
    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_bigint_id_migration).and_return(skip_bigint_id_migration)
    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:migration_psql_concurrent_statement_timeout_in_seconds).and_return(300)
  end

  describe 'up' do
    context 'when migration step 1 was executed and id_bigint column was added' do
      before do
        insert.call(db)
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
      end

      it 'fails when backfilling is incomplete' do
        expect do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true)
        end.to raise_error(/Failed to add check constraint on '#{table}' table!/)

        db[table].delete # required: migration shared context's after block will re-run step3a
      end

      it 'adds check constraint after backfill is complete' do
        VCAP::BigintMigration.backfill(logger, db, table)

        expect(db).not_to have_table_with_check_constraint(table)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true) }.not_to raise_error

        expect(db).to have_table_with_check_constraint(table)
      end
    end

    context "when migration step 1 concluded (empty table: id column's type switched)" do
      before do
        db[table].delete
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
      end

      it 'does not add a check constraint' do
        expect(db).not_to have_table_with_check_constraint(table)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true) }.not_to raise_error

        expect(db).not_to have_table_with_check_constraint(table)
      end
    end

    context 'when migration step 1 was skipped' do
      let(:skip_bigint_id_migration) { true }

      before do
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
      end

      it 'does not add a check constraint' do
        expect(db).not_to have_table_with_check_constraint(table)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true) }.not_to raise_error

        expect(db).not_to have_table_with_check_constraint(table)
      end
    end
  end

  describe 'down' do
    before do
      insert.call(db)
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
      VCAP::BigintMigration.backfill(logger, db, table)
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true)
    end

    it 'drops the check constraint' do
      expect(db).to have_table_with_check_constraint(table)

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a - 1, allow_missing_migration_files: true) }.not_to raise_error

      expect(db).not_to have_table_with_check_constraint(table)
    end
  end
end

RSpec.shared_context 'bigint migration step3b' do
  before(:all) { skip unless Sequel::Model.db.database_type == :postgres } # rubocop:disable RSpec/BeforeAfterAll

  let(:migration_filename) { migration_filename_step1 }
  let(:current_migration_index_step3a) { migration_filename_step3a.match(/\A\d+/)[0].to_i }
  let(:current_migration_index_step3b) { migration_filename_step3b.match(/\A\d+/)[0].to_i }

  include_context 'migration'

  let(:skip_bigint_id_migration) { false }
  let(:logger) { double(:logger, info: nil) }

  before do
    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_bigint_id_migration).and_return(skip_bigint_id_migration)
    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:migration_psql_concurrent_statement_timeout_in_seconds).and_return(300)
  end

  describe 'up' do
    before do
      insert.call(db)
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
      VCAP::BigintMigration.backfill(logger, db, table)
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true)
    end

    it 'completes bigint migration: drops constraints/trigger, renames columns, maintains primary key; identity sequence is correct' do
      # Verify pre-migration state
      expect(db).to have_table_with_check_constraint(table)
      expect(db).to have_trigger_function_for_table(table)
      expect(db).to have_table_with_column_and_type(table, :id, 'integer')
      expect(db).to have_table_with_column_and_type(table, :id_bigint, 'bigint')
      expect(db).to have_table_with_primary_key(table, :id)

      last_id_before_migration = insert.call(db)

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b, allow_missing_migration_files: true) }.not_to raise_error

      # Verify post-migration state
      expect(db).not_to have_table_with_check_constraint(table)
      expect(db).not_to have_trigger_function_for_table(table)
      expect(db).to have_table_with_column_and_type(table, :id, 'bigint')
      expect(db).not_to have_table_with_column(table, :id_bigint)
      expect(db).to have_table_with_primary_key(table, :id)

      # Identity sequence continues from the last id
      first_id_after_migration = insert.call(db)
      expect(first_id_after_migration).to eq(last_id_before_migration + 1)

      # Timestamp index preserved if applicable
      expect(db).to have_table_with_index_on_columns(table, %i[timestamp id]) if db.schema(table).any? { |col| col[0] == :timestamp }
    end
  end

  describe 'down' do
    before do
      insert.call(db)
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
      VCAP::BigintMigration.backfill(logger, db, table)
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true)
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b, allow_missing_migration_files: true)
    end

    it 'reverts bigint migration: restores columns, constraints, trigger, indexes; identity sequence is correct' do
      # Verify pre-rollback state
      expect(db).to have_table_with_column_and_type(table, :id, 'bigint')
      expect(db).not_to have_table_with_column(table, :id_bigint)
      expect(db).to have_table_with_primary_key(table, :id)
      expect(db).not_to have_trigger_function_for_table(table)
      expect(db).not_to have_table_with_check_constraint(table)

      last_id_before_rollback = insert.call(db)

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b - 1, allow_missing_migration_files: true) }.not_to raise_error

      # Verify post-rollback state
      expect(db).to have_table_with_column_and_type(table, :id, 'integer')
      expect(db).to have_table_with_column_and_type(table, :id_bigint, 'bigint')
      expect(db).to have_table_with_column_and_attribute(table, :id_bigint, :allow_null, true)
      expect(db).to have_table_with_primary_key(table, :id)
      expect(db).to have_trigger_function_for_table(table)
      expect(db).to have_table_with_check_constraint(table)

      # Identity sequence continues from the last id
      first_id_after_rollback = insert.call(db)
      expect(first_id_after_rollback).to eq(last_id_before_rollback + 1)

      # Timestamp index reverted if applicable
      if db.schema(table).any? { |col| col[0] == :timestamp }
        expect(db).to have_table_with_index_on_columns(table, %i[timestamp id])
        expect(db).not_to have_table_with_index_on_columns(table, %i[timestamp id_bigint])
      end
    end
  end
end
# rubocop:enable Migration/TooManyMigrationRuns
