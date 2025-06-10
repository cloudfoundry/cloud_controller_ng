require 'migrations/helpers/migration_shared_context'
require 'database/bigint_migration'

RSpec.shared_context 'bigint migration step3a' do
  subject(:run_migration_step1) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }

  subject(:run_migration_step3a) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true) }

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
          run_migration_step1
        end

        context 'when backfilling was completed' do
          before do
            VCAP::BigintMigration.backfill(logger, db, table)
          end

          it 'adds a check constraint' do
            expect(db).not_to have_table_with_check_constraint(table)

            run_migration_step3a

            expect(db).to have_table_with_check_constraint(table)
          end
        end

        context 'when backfilling was not completed' do
          after do
            db[table].delete # Necessary as the migration will be executed again in the after block of the migration shared context - and should not fail...
          end

          it 'fails ...' do
            expect do
              run_migration_step3a
            end.to raise_error(/Failed to add check constraint on 'events' table!/)
          end
        end
      end

      context "when the migration was concluded (id column's type switched)" do
        before do
          db[table].delete
          run_migration_step1
        end

        it 'does not add a check constraint' do
          expect(db).not_to have_table_with_check_constraint(table)

          run_migration_step3a

          expect(db).not_to have_table_with_check_constraint(table)
        end
      end
    end

    context 'when migration step 1 was skipped' do
      let(:skip_bigint_id_migration) { true }

      before do
        run_migration_step1
      end

      it 'does not add a check constraint' do
        expect(db).not_to have_table_with_check_constraint(table)

        run_migration_step3a

        expect(db).not_to have_table_with_check_constraint(table)
      end
    end
  end

  describe 'down' do
    subject(:run_rollback_step3a) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a - 1, allow_missing_migration_files: true) }

    context 'when migration step 3a was executed' do
      before do
        insert.call(db)
        run_migration_step1
        VCAP::BigintMigration.backfill(logger, db, table)
        run_migration_step3a
      end

      it 'drops the check constraint' do
        expect(db).to have_table_with_check_constraint(table)

        run_rollback_step3a

        expect(db).not_to have_table_with_check_constraint(table)
      end
    end
  end
end

RSpec.shared_context 'bigint migration step3b' do
  subject(:run_migration_step1) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }

  subject(:run_migration_step3a) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3a, allow_missing_migration_files: true) }

  subject(:run_migration_step3b) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b, allow_missing_migration_files: true) }

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
        run_migration_step1
        VCAP::BigintMigration.backfill(logger, db, table)
        run_migration_step3a
      end

      it 'drops the check constraint' do
        expect(db).to have_table_with_check_constraint(table)

        run_migration_step3b

        expect(db).not_to have_table_with_check_constraint(table)
      end

      it 'drops the trigger function' do
        expect(db).to have_trigger_function_for_table(table)

        run_migration_step3b

        expect(db).not_to have_trigger_function_for_table(table)
      end

      it 'drops the id column and renames the id_bigint column to id' do
        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).to have_table_with_column_and_type(table, :id_bigint, 'bigint')

        run_migration_step3b

        expect(db).to have_table_with_column_and_type(table, :id, 'bigint')
        expect(db).not_to have_table_with_column(table, :id_bigint)
      end

      it 'uses the (bigint) id column as primary key' do
        expect(db).to have_table_with_primary_key(table, :id)

        run_migration_step3b

        expect(db).to have_table_with_primary_key(table, :id)
      end

      it 'has an index on timestamp + (bigint) id column' do
        expect(db).to have_table_with_index_on_columns(table, %i[timestamp id])

        run_migration_step3b

        expect(db).to have_table_with_index_on_columns(table, %i[timestamp id])
      end

      it 'uses an identity with correct start value for the (bigint) id column' do
        last_id_before_migration = insert.call(db)

        run_migration_step3b

        first_id_after_migration = insert.call(db)
        expect(first_id_after_migration).to eq(last_id_before_migration + 1)
      end
    end
  end

  describe 'down' do
    subject(:run_rollback_step3b) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index_step3b - 1, allow_missing_migration_files: true) }

    context 'when migration step 3b was executed' do
      before do
        insert.call(db)
        run_migration_step1
        VCAP::BigintMigration.backfill(logger, db, table)
        run_migration_step3a
        run_migration_step3b
      end

      it 'uses an identity with correct start value for the (integer) id column' do
        last_id_before_migration = insert.call(db)

        run_rollback_step3b

        first_id_after_migration = insert.call(db)
        expect(first_id_after_migration).to eq(last_id_before_migration + 1)
      end

      it 'has an index on timestamp + (integer) id column' do
        expect(db).to have_table_with_index_on_columns(table, %i[timestamp id])

        run_rollback_step3b

        expect(db).to have_table_with_index_on_columns(table, %i[timestamp id])
        expect(db).not_to have_table_with_index_on_columns(table, %i[timestamp id_bigint])
      end

      it 'uses the (integer) id column as primary key' do
        expect(db).to have_table_with_primary_key(table, :id)

        run_rollback_step3b

        expect(db).to have_table_with_primary_key(table, :id)
      end

      it 'renames the id column to id_bigint and re-adds the (integer) id column' do
        expect(db).to have_table_with_column_and_type(table, :id, 'bigint')
        expect(db).not_to have_table_with_column(table, :id_bigint)

        run_rollback_step3b

        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).to have_table_with_column_and_type(table, :id_bigint, 'bigint')
        expect(db).to have_table_with_column_and_attribute(table, :id_bigint, :allow_null, true)
      end

      it 're-creates the trigger function' do
        expect(db).not_to have_trigger_function_for_table(table)

        run_rollback_step3b

        expect(db).to have_trigger_function_for_table(table)
      end

      it 're-adds the check constraint (this also ensures that id was correctly backfilled)' do
        expect(db).not_to have_table_with_check_constraint(table)

        run_rollback_step3b

        expect(db).to have_table_with_check_constraint(table)
      end
    end
  end
end
