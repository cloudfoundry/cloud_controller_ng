require 'spec_helper'

RSpec.describe DBMigrator do
  describe '#wait_for_migrations!' do
    let(:migrator) { DBMigrator.new(db, 1) }
    let(:db) { double(:db) }

    it 'blocks until migrations are current or newer' do
      expect(Sequel::Migrator).to receive(:is_current?).with(
        db,
        DBMigrator::SEQUEL_MIGRATIONS,
        allow_missing_migration_files: true,
      ).and_return(false, false, true)

      expect(Timeout).to receive(:timeout).with(60, anything).and_yield
      allow_any_instance_of(Object).to receive(:sleep).with(1).and_return(1)
      expect {
        migrator.wait_for_migrations!
      }.not_to raise_error
    end

    it 'doesnt block when migrations are already current' do
      expect(Sequel::Migrator).to receive(:is_current?).with(
        db,
        DBMigrator::SEQUEL_MIGRATIONS,
        allow_missing_migration_files: true,
      ).and_return(true).at_most(2).times

      expect(Timeout).to receive(:timeout).with(60, anything).and_yield
      expect_any_instance_of(Object).not_to receive(:sleep)
      expect {
        migrator.wait_for_migrations!
      }.not_to raise_error
    end

    it 'times out after max_migration_duration_in_minutes' do
      expect(Timeout).to receive(:timeout).with(60, anything).and_throw(Timeout::Error)

      expect(Sequel::Migrator).to receive(:is_current?).with(
        db,
        DBMigrator::SEQUEL_MIGRATIONS,
        allow_missing_migration_files: true,
      ).and_return(false)

      expect {
        migrator.wait_for_migrations!
      }.to raise_error(UncaughtThrowError)
    end
  end
end
