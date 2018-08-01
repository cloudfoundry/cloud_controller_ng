require 'spec_helper'

RSpec.describe DBMigrator do
  describe '#check_migrations!' do
    context 'when the migrations have not run' do
      it 'raises an exception' do
        db = double(:db)
        migrator = DBMigrator.new(db)

        expect(Sequel::Migrator).to receive(:check_current).with(db, DBMigrator::SEQUEL_MIGRATIONS).and_raise(Sequel::Migrator::NotCurrentError)
        expect {
          migrator.check_migrations!
        }.to raise_error(Sequel::Migrator::NotCurrentError)
      end
    end
  end
end
