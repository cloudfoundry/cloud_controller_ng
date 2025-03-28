require 'migrations/helpers/migration_shared_context'

RSpec.shared_context 'bigint migration step1' do
  subject(:run_migration) do
    rake_context = RakeConfig.context
    RakeConfig.context = :migrate
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
  ensure
    RakeConfig.context = rake_context
  end

  include_context 'migration'

  let(:skip_bigint_id_migration) { nil }

  before do
    fake_config = double
    allow(fake_config).to receive(:get).with(:skip_bigint_id_migration).and_return(skip_bigint_id_migration)
    allow(RakeConfig).to receive(:config).and_return(fake_config)
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
        before do
          db[table].insert(insert_hash)
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

  # down
end
