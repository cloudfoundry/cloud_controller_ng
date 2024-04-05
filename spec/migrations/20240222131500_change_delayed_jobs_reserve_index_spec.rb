require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to change the delayed_jobs_reserve index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240222131500_change_delayed_jobs_reserve_index.rb' }
  end

  it 'succeeds' do
    Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true)
  end
end
