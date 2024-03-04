require 'spec_helper'

RSpec.describe 'migration ccdb logs to elk', isolation: :truncation, type: :migration do
  let(:db) { Sequel::Model.db }
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    logger = instance_double(Steno::Logger)
    allow(Steno).to receive(:logger).and_return(logger)

    allow(logger).to receive(:info)

    long_time_migration = <<-MIGRATION
      Sequel.migration do
        up do
          10.times do
            Steno.logger('cc.db.migrations').info('still migrating')
          end
          Steno.logger('cc.db.migrations').info('migration finished')
        end
        down do
        end
      end
    MIGRATION

    migration_file = "#{tmp_migrations_dir}/001_test_for_long_time_migration.rb"
    File.write(migration_file, long_time_migration)
    Sequel::Migrator.run(db, tmp_migrations_dir, target: 0, allow_missing_migration_files: true)
  end

  after do
    Sequel::Migrator.run(db, tmp_migrations_dir, allow_missing_migration_files: true)
    FileUtils.rm_rf(tmp_migrations_dir)
  end

  it 'calls logger.info 11 times' do
    expect(Steno.logger('cc.db.migrations')).to receive(:info).exactly(11).times
  end

  it "logger.info should be called with 'still migrating' 10 times" do
    expect(Steno.logger('cc.db.migrations')).to receive(:info).with('still migrating').exactly(10).times
  end

  it "logger.info should be called with 'migration finished' once" do
    expect(Steno.logger('cc.db.migrations')).to receive(:info).with('migration finished').once
  end
end
