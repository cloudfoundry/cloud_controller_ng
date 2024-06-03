require 'spec_helper'

RSpec.describe DBMigrator, isolation: :truncation, type: :migration do
  let(:db) { Sequel::Model.db }

  describe '#wait_for_migrations!' do
    let(:migrator) { DBMigrator.new(db, 1) }

    it 'blocks until migrations are current or newer' do
      expect(Sequel::Migrator).to receive(:is_current?).with(
        db,
        DBMigrator::SEQUEL_MIGRATIONS,
        allow_missing_migration_files: true
      ).and_return(false, false, true)

      expect(Timeout).to receive(:timeout).with(60, anything).and_yield
      allow_any_instance_of(Object).to receive(:sleep).with(1).and_return(1)
      expect do
        migrator.wait_for_migrations!
      end.not_to raise_error
    end

    it 'doesnt block when migrations are already current' do
      expect(Sequel::Migrator).to receive(:is_current?).with(
        db,
        DBMigrator::SEQUEL_MIGRATIONS,
        allow_missing_migration_files: true
      ).and_return(true).at_most(:twice)

      expect(Timeout).to receive(:timeout).with(60, anything).and_yield
      expect_any_instance_of(Object).not_to receive(:sleep)
      expect do
        migrator.wait_for_migrations!
      end.not_to raise_error
    end

    it 'times out after max_migration_duration_in_minutes' do
      expect(Timeout).to receive(:timeout).with(60, anything).and_throw(Timeout::Error)

      expect(Sequel::Migrator).to receive(:is_current?).with(
        db,
        DBMigrator::SEQUEL_MIGRATIONS,
        allow_missing_migration_files: true
      ).and_return(false)

      expect do
        migrator.wait_for_migrations!
      end.to raise_error(UncaughtThrowError)
    end
  end

  describe 'postgresql' do
    it 'sets a default statement timeout' do
      skip if db.database_type != :postgres
      expect(db).to receive(:run).with('SET statement_timeout TO 30000')
      DBMigrator.new(db)
    end

    it 'sets a config provided statement timeout' do
      skip if db.database_type != :postgres
      expect(db).to receive(:run).with('SET statement_timeout TO 60000')
      DBMigrator.new(db, nil, 60)
    end

    it 'does not set worker_mem' do
      skip if db.database_type != :postgres
      expect(db).to receive(:run) # required for 'SET statement_timeout'
      expect(db).not_to receive(:run).with('SET work_mem = 1234')
      DBMigrator.new(db, nil, nil)
    end

    it 'sets worker_mem to provided value' do
      skip if db.database_type != :postgres
      expect(db).to receive(:run) # required for 'SET statement_timeout'
      expect(db).to receive(:run).with('SET work_mem = 1234')
      DBMigrator.new(db, nil, nil, 1234)
    end
  end

  describe 'benchmark' do
    let(:migrator) { DBMigrator.new(db) }

    it 'runs migrations without benchmark' do
      expect(Benchmark).not_to receive(:measure)
      migrator.apply_migrations
    end

    context 'when setting WITH_BENCHMARK env' do
      before { ENV['WITH_BENCHMARK'] = 'true' }

      it 'runs migrations with benchmark' do
        expect(Benchmark).to receive(:measure).and_return(double(:bm_output, total: 1, stime: 2, utime: 3, real: 4))
        expect { migrator.apply_migrations }.to output(/Starting migrations with benchmark/).to_stdout
      end
    end
  end
end
