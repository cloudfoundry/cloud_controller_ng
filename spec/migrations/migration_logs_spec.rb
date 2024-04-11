require 'spec_helper'

RSpec.describe 'migration logs', isolation: :truncation, type: :migration do
  let(:db) { Sequel::Model.db }
  let(:tmp_migrations_dir) { Dir.mktmpdir }
  let(:logger) { instance_double(Steno::Logger) }

  before do
    long_time_migration = <<-MIGRATION
      Sequel.migration do
        up do
          10.times do
            VCAP::Migration.logger.info('Still Migrating')
          end
          VCAP::Migration.logger.info('migration finished')
        end
        down do
        end
      end
    MIGRATION

    migration_file = "#{tmp_migrations_dir}/001_test_for_long_time_migration.rb"
    File.write(migration_file, long_time_migration)
  end

  after do
    Sequel::Migrator.run(db, tmp_migrations_dir, target: 0, allow_missing_migration_files: true)
    FileUtils.rm_rf(tmp_migrations_dir)
  end

  it 'runs the up migration without errors' do
    allow(Steno).to receive(:logger).with('cc.db.migrations').and_return(logger)
    expect(logger).to receive(:info).with('Still Migrating').exactly(10).times
    expect(logger).to receive(:info).with('migration finished').once
    expect { Sequel::Migrator.run(db, tmp_migrations_dir, allow_missing_migration_files: true) }.not_to raise_error
  end
end
