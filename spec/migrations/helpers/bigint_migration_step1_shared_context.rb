require 'migrations/helpers/migration_shared_context'
require 'database/bigint_migration'

RSpec.shared_context 'bigint migration step1' do
  subject(:run_migration) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }

  include_context 'migration'

  let(:skip_bigint_id_migration) { nil }

  before do
    skip unless db.database_type == :postgres

    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_bigint_id_migration).and_return(skip_bigint_id_migration)
    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:migration_psql_concurrent_statement_timeout_in_seconds).and_return(300)
  end

  describe 'up' do
    context 'when skip_bigint_id_migration is false' do
      let(:skip_bigint_id_migration) { false }
      let(:logger) { double(:logger, info: nil) }

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      context 'when the table is empty' do
        before do
          db[table].delete
        end

        it "changes the id column's type to bigint" do
          expect(db).to have_table_with_column_and_type(table, :id, 'integer')

          run_migration

          expect(db).to have_table_with_column_and_type(table, :id, 'bigint')
        end

        it 'does not add the id_bigint column' do
          expect(db).not_to have_table_with_column(table, :id_bigint)

          run_migration

          expect(db).not_to have_table_with_column(table, :id_bigint)
        end

        describe 'backfill' do
          before do
            run_migration
          end

          it 'fails with a proper error message' do
            expect do
              VCAP::BigintMigration.backfill(logger, db, table)
            end.to raise_error(RuntimeError, /table '#{table}' does not contain column 'id_bigint'/)
          end
        end
      end

      context 'when the table is not empty' do
        let!(:old_id) { insert.call(db) }

        after do
          db[table].delete # Necessary to successfully run subsequent migrations in the after block of the migration shared context...
        end

        it "does not change the id column's type" do
          expect(db).to have_table_with_column_and_type(table, :id, 'integer')

          run_migration

          expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        end

        it 'adds the id_bigint column' do
          expect(db).not_to have_table_with_column(table, :id_bigint)

          run_migration

          expect(db).to have_table_with_column_and_type(table, :id_bigint, 'bigint')
        end

        it 'creates the trigger function' do
          expect(db).not_to have_trigger_function_for_table(table)

          run_migration

          expect(db).to have_trigger_function_for_table(table)
        end

        it 'does not populate the id_bigint column for an existing entry' do
          run_migration

          expect(db[table].where(id: old_id).get(:id_bigint)).to be_nil
        end

        it 'automatically populates the id_bigint column for a new entry' do
          run_migration

          new_id = insert.call(db)
          expect(db[table].where(id: new_id).get(:id_bigint)).to eq(new_id)
        end

        describe 'backfill' do
          before do
            100.times { insert.call(db) }

            run_migration
          end

          context 'default batch size' do
            it 'backfills all entries in a single run' do
              expect(db).to have_table_with_unpopulated_column(table, :id_bigint)

              expect do
                VCAP::BigintMigration.backfill(logger, db, table)
              end.to have_queried_db_times(/update/i, 1)

              expect(db).not_to have_table_with_unpopulated_column(table, :id_bigint)
            end
          end

          context 'custom batch size' do
            let(:batch_size) { 30 }

            it 'backfills entries in multiple runs' do
              expect(db).to have_table_with_unpopulated_column(table, :id_bigint)

              expect do
                VCAP::BigintMigration.backfill(logger, db, table, batch_size:)
              end.to have_queried_db_times(/update/i, 4)

              expect(db).not_to have_table_with_unpopulated_column(table, :id_bigint)
            end

            context 'limited number of iterations' do
              let(:iterations) { 2 }

              it 'stops backfilling' do
                expect(db).to have_table_with_unpopulated_column(table, :id_bigint)

                expect do
                  VCAP::BigintMigration.backfill(logger, db, table, batch_size:, iterations:)
                end.to have_queried_db_times(/update/i, 2)

                expect(db).to have_table_with_unpopulated_column(table, :id_bigint)
              end
            end
          end
        end
      end
    end

    context 'when skip_bigint_id_migration is true' do
      let(:skip_bigint_id_migration) { true }

      it "neither changes the id column's type, nor adds the id_bigint column" do
        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).not_to have_table_with_column(table, :id_bigint)

        run_migration

        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
        expect(db).not_to have_table_with_column(table, :id_bigint)
      end
    end
  end

  describe 'down' do
    subject(:run_rollback) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }

    context 'when the table is empty' do
      before do
        db[table].delete
        run_migration
      end

      it "reverts the id column's type to integer" do
        expect(db).to have_table_with_column_and_type(table, :id, 'bigint')

        run_rollback

        expect(db).to have_table_with_column_and_type(table, :id, 'integer')
      end
    end

    context 'when the table is not empty' do
      before do
        insert.call(db)
        run_migration
      end

      after do
        db[table].delete # Necessary to successfully run subsequent migrations in the after block of the migration shared context...
      end

      it 'drops the id_bigint column' do
        expect(db).to have_table_with_column(table, :id_bigint)

        run_rollback

        expect(db).not_to have_table_with_column(table, :id_bigint)
      end

      it 'drops the trigger function' do
        expect(db).to have_trigger_function_for_table(table)

        run_rollback

        expect(db).not_to have_trigger_function_for_table(table)
      end
    end
  end
end
