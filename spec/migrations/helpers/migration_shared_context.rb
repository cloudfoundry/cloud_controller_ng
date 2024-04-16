require 'migrations/helpers/matchers'

RSpec.shared_context 'migration' do
  let(:migrations_path) { DBMigrator::SEQUEL_MIGRATIONS }
  let(:db) { Sequel::Model.db }
  let(:current_migration_index) { migration_filename.match(/\A\d+/)[0].to_i }

  before do
    allow(db).to receive(:add_index).with(anything, anything, add_index_options).and_call_original
    allow(db).to receive(:drop_index).with(anything, anything, drop_index_options).and_call_original

    Sequel.extension :migration

    # Revert the given migration and everything newer so we are at the database version exactly before our migration we want to test.
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)
  end

  after do
    all_migration_filepaths = Dir.glob(sprintf('%s/*.rb', migrations_path))
    last_migration_file_name = all_migration_filepaths[-1].split('/')[-1]
    last_migration_index = last_migration_file_name.match(/\A\d+/)[0].to_i

    # Complete the migration to not leave the test database half migrated and following tests fail due to this
    Sequel::Migrator.run(db, migrations_path, target: last_migration_index, allow_missing_migration_files: true)
  end
end
