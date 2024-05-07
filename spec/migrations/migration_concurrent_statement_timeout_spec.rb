require 'spec_helper'

RSpec.describe 'migration concurrent statement timeout', isolation: :truncation, type: :migration do
  let(:db) { Sequel::Model.db }
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    long_time_migration = <<-MIGRATION
      Sequel.migration do
        up do
          VCAP::Migration.with_concurrent_timeout(self) do
            VCAP::Migration.logger.info('Migrating')
          end
        end
        down do
        end
      end
    MIGRATION

    migration_file = "#{tmp_migrations_dir}/001_test_for_concurrent_statement_timeout_migration.rb"
    File.write(migration_file, long_time_migration)

    allow(VCAP::CloudController::Config.config).to receive(:get).with(:migration_psql_concurrent_statement_timeout_in_seconds).and_return(1899)
    allow(db).to receive(:run).and_call_original
  end

  after do
    Sequel::Migrator.run(db, tmp_migrations_dir, target: 0, allow_missing_migration_files: true)
    FileUtils.rm_rf(tmp_migrations_dir)
  end

  it 'increases the statement timeout for concurrent statements' do
    skip if db.database_type != :postgres
    expect { Sequel::Migrator.run(db, tmp_migrations_dir, allow_missing_migration_files: true) }.not_to raise_error
    expect(db).to have_received(:run).exactly(2).times
    expect(db).to have_received(:run).with(/SET statement_timeout TO \d+/).twice
    expect(db).to have_received(:run).with('SET statement_timeout TO 1899000').once
  end
end
