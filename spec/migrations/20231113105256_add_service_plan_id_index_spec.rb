require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add the service_plan_id index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20231113105256_add_service_plan_id_index.rb' }
  end

  it 'succeeds' do
    Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true)
  end
end
