require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add the routes_space_id index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240219113000_add_routes_space_id_index.rb' }
  end

  # The migration body is a no-op on MySQL, so only exercise it on PostgreSQL.
  it 'adds and removes the index and is idempotent' do
    skip if db.database_type != :postgres

    expect(db.indexes(:routes)).not_to include(:routes_space_id_index)

    expect { run_migration }.not_to raise_error
    expect(db.indexes(:routes)).to include(:routes_space_id_index)

    test_up_migration_idempotency
    expect(db.indexes(:routes)).to include(:routes_space_id_index)

    expect { revert_migration }.not_to raise_error
    expect(db.indexes(:routes)).not_to include(:routes_space_id_index)

    test_down_migration_idempotency
    expect(db.indexes(:routes)).not_to include(:routes_space_id_index)
  end
end
