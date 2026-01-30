require 'migrations/helpers/migration_shared_context'
require 'database/bigint_migration'

RSpec.shared_context 'bigint migration step3a' do
  let(:migration_filename) { migration_filename_step1 }
  let(:current_migration_index_step3a) { migration_filename_step3a.match(/\A\d+/)[0].to_i }

  include_context 'migration'

  let(:skip_bigint_id_migration) { false }
  let(:logger) { double(:logger, info: nil) }

  before do
    skip unless db.database_type == :postgres

    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_bigint_id_migration).and_return(skip_bigint_id_migration)
    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:migration_psql_concurrent_statement_timeout_in_seconds).and_return(300)
  end

  describe 'up' do
    context 'when migration step 1 was executed' do
      context 'when the id_bigint column was added' do
        before do
          insert.call(db)
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
        end

        context 'when backfilling was completed' do
          before do
            VCAP::BigintMigration.backfill(logger, db, table)
          end

          it 'adds a check constraint' do
            expect(db).not_to have_table_with_check_constraint(table)

            expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true) }.not_to raise_error

            expect(db).to have_table_with_check_constraint(table)
          end
        end

        context 'when backfilling was not completed' do
          after do
            db[table].delete # Necessary as the migration will be executed again in the after block of the migration shared context - and should not fail...
          end

          it 'fails ...' do
            expect do
              Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true)
            end.to raise_error(/Failed to add check constraint on '#{table}' table!/)
          end
        end
      end

      context "when the migration was concluded (id column's type switched)" do
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
    context 'when migration step 3a was executed' do
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
end

RSpec.shared_context 'bigint migration step3b' do
  let(:migration_filename) { migration_filename_step1 }
  let(:current_migration_index_step3a) { migration_filename_step3a.match(/\A\d+/)[0].to_i }
  let(:current_migration_index_step3b) { migration_filename_step3b.match(/\A\d+/)[0].to_i }

  include_context 'migration'

  let(:skip_bigint_id_migration) { false }
  let(:logger) { double(:logger, info: nil) }

  before do
    skip unless db.database_type == :postgres

    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_bigint_id_migration).and_return(skip_bigint_id_migration)
    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:migration_psql_concurrent_statement_timeout_in_seconds).and_return(300)
  end

  describe 'up' do
    context 'when migration step 3a was executed' do
      before do
        insert.call(db)
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
        VCAP::BigintMigration.backfill(logger, db, table)
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true)
      end

      it 'completes the bigint migration: drops constraints, renames columns, and maintains primary key' do
        # Verify pre-migration state
        expect(db).to have_table_with_check_constraint(table)
        expect(db).to have_trigger_function_for_table(table)
        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).to have_table_with_column_and_type(table, :id_bigint, 'bigint')
        expect(db).to have_table_with_primary_key(table, :id)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b, allow_missing_migration_files: true) }.not_to raise_error

        # Verify post-migration state
        expect(db).not_to have_table_with_check_constraint(table)
        expect(db).not_to have_trigger_function_for_table(table)
        expect(db).to have_table_with_column_and_type(table, :id, 'bigint')
        expect(db).not_to have_table_with_column(table, :id_bigint)

        expect(db).to have_table_with_primary_key(table, :id)
      end

      it 'has an index on timestamp + (bigint) id column' do
        if db.schema(table).any? { |col| col[0] == :timestamp }

          expect(db).to have_table_with_index_on_columns(table, %i[timestamp id])

          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b, allow_missing_migration_files: true) }.not_to raise_error

          expect(db).to have_table_with_index_on_columns(table, %i[timestamp id])
        end
      end

      it 'uses an identity with correct start value for the (bigint) id column' do
        last_id_before_migration = insert.call(db)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b, allow_missing_migration_files: true) }.not_to raise_error

        first_id_after_migration = insert.call(db)
        expect(first_id_after_migration).to eq(last_id_before_migration + 1)
      end
    end
  end

  describe 'down' do
    context 'when migration step 3b was executed' do
      before do
        insert.call(db)
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
        VCAP::BigintMigration.backfill(logger, db, table)
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true)
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b, allow_missing_migration_files: true)
      end

      it 'uses an identity with correct start value for the (integer) id column' do
        last_id_before_migration = insert.call(db)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b - 1, allow_missing_migration_files: true) }.not_to raise_error

        first_id_after_migration = insert.call(db)
        expect(first_id_after_migration).to eq(last_id_before_migration + 1)
      end

      it 'reverts the bigint migration: restores columns, constraints, and indexes' do
        # Verify pre-rollback state
        expect(db).to have_table_with_column_and_type(table, :id, 'bigint')
        expect(db).not_to have_table_with_column(table, :id_bigint)
        expect(db).to have_table_with_primary_key(table, :id)
        expect(db).not_to have_trigger_function_for_table(table)
        expect(db).not_to have_table_with_check_constraint(table)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b - 1, allow_missing_migration_files: true) }.not_to raise_error

        # Verify post-rollback state
        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).to have_table_with_column_and_type(table, :id_bigint, 'bigint')
        expect(db).to have_table_with_column_and_attribute(table, :id_bigint, :allow_null, true)
        expect(db).to have_table_with_primary_key(table, :id)
        expect(db).to have_trigger_function_for_table(table)
        expect(db).to have_table_with_check_constraint(table)

        # Verify timestamp index if applicable
        if db.schema(table).any? { |col| col[0] == :timestamp }
          expect(db).to have_table_with_index_on_columns(table, %i[timestamp id])
          expect(db).not_to have_table_with_index_on_columns(table, %i[timestamp id_bigint])
        end
      end
    end
  end
end
