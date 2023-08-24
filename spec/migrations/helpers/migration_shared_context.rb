RSpec.shared_context 'migration' do
  let(:all_migrations) { Dir.mktmpdir }
  let(:down_migrations) { Dir.mktmpdir }
  let(:migration_to_test) { Dir.mktmpdir }
  let(:db) { Sequel::Model.db }

  before(:each) do
    Sequel.extension :migration
    # Find all migrations
    migration_files = Dir.glob(sprintf('%s/*.rb', DBMigrator::SEQUEL_MIGRATIONS))
    # Calculate the index of our migration file we`d like to test
    migration_index = migration_files.find_index { |file| file.end_with?(migration_filename) }
    # Make a file list of the migration file we like to test plus all migrations after the one we want to test
    migration_files_after_test = migration_files[migration_index...]
    # Copy them to a temp directory
    FileUtils.cp(migration_files, all_migrations)
    FileUtils.cp(migration_files_after_test, down_migrations)
    FileUtils.cp(File.join(DBMigrator::SEQUEL_MIGRATIONS, migration_filename), migration_to_test)
    # Revert the given migration and everything newer so we are at the database version exactly before our migration we want to test.
    Sequel::Migrator.run(db, down_migrations, target: 0, allow_missing_migration_files: true)
  end

  after(:each) do
    FileUtils.rm_rf(migration_to_test)
    FileUtils.rm_rf(down_migrations)

    # Complete the migration to not leave the test database half migrated and following tests fail due to this
    Sequel::Migrator.run(db, all_migrations, allow_missing_migration_files: true)
    FileUtils.rm_rf(all_migrations)
  end
end
