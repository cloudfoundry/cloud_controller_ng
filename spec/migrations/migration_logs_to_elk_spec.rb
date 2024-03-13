require 'spec_helper'

RSpec.describe 'migration ccdb logs to elk', isolation: :truncation, type: :migration do
  let(:db) { Sequel::Model.db }
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    long_time_migration = <<-MIGRATION
      Sequel.migration do
        up do
          10.times do
            VCAP::Migration.logging('Still Migrating')
          end
          VCAP::Migration.logging('migration finished')
        end
        down do
        end
      end
    MIGRATION

    migration_file = "#{tmp_migrations_dir}/001_test_for_long_time_migration.rb"
    File.write(migration_file, long_time_migration)
  end

  after do
    Sequel::Migrator.run(db, tmp_migrations_dir, allow_missing_migration_files: true)
    FileUtils.rm_rf(tmp_migrations_dir)
  end

  it 'runs the up migration without errors' do
    allow(VCAP::Migration).to receive(:logging)
    expect(VCAP::Migration).to receive(:logging).with('Still Migrating').exactly(10).times
    expect(VCAP::Migration).to receive(:logging).with('migration finished').once
    expect { Sequel::Migrator.run(db, tmp_migrations_dir, target: 0, allow_missing_migration_files: true) }.not_to raise_error
  end
end
