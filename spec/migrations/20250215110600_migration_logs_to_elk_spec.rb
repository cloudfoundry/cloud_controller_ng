require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration ccdb logs to elk', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250215110600_migration_logs_to_elk.rb' }
  end

  before do
    @logger = instance_double(Steno::Logger)

    allow(Steno).to receive(:logger).and_return(@logger)
  end

  describe 'migration' do
    it 'calls logger.info with "still migrating"' do
      expect { Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true) }.not_to raise_error
      expect(@logger).to receive(:info).with('still migrating').exactly(100).times
    end

    it 'calls logger.info with "migration finished"' do
      expect { Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true) }.not_to raise_error
      expect(@logger).to receive(:info).with('migration finished').once
    end
  end
end
