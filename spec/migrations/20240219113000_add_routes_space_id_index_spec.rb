require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add the routes_space_id index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240219113000_add_routes_space_id_index.rb' }
  end

  it 'succeeds' do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
  end
end
