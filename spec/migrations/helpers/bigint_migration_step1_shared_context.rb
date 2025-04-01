require 'migrations/helpers/migration_shared_context'

RSpec.shared_context 'bigint migration step1' do
  subject(:run_migration) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }

  include_context 'migration'

  let(:skip_bigint_id_migration) { nil }

  before do
    skip unless db.database_type == :postgres

    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_bigint_id_migration).and_return(skip_bigint_id_migration)
  end

  describe 'up' do
    context 'when skip_bigint_id_migration is false' do
      let(:skip_bigint_id_migration) { false }

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
      end

      context 'when the table is not empty' do
        let!(:old_id) { insert.call(db) }

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
