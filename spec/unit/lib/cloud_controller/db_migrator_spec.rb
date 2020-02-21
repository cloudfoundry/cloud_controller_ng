require 'spec_helper'

RSpec.describe DBMigrator do
  describe '#check_migrations!' do
    context 'when the migrations have not run' do
      it 'blocks until migrations are current or newer' do
        db = double(:db)
        migrator = DBMigrator.new(db)

        expect(Sequel::Migrator).to receive(:is_current?).with(db, DBMigrator::SEQUEL_MIGRATIONS, allow_missing_migration_files: true).and_return(false, false, true)
        allow_any_instance_of(Object).to receive(:sleep).with(1).and_return(1)
        expect {
          migrator.check_migrations!
        }.not_to raise_error
      end
    end
  end
end
