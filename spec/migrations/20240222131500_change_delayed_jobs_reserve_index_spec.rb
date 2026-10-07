require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to change the delayed_jobs_reserve index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240222131500_change_delayed_jobs_reserve_index.rb' }
  end

  # The migration body is a no-op on MySQL, so only exercise it on PostgreSQL.
  it 'changes the index and is idempotent' do
    skip if db.database_type != :postgres

    expect { run_migration }.not_to raise_error
    expect(db.indexes(:delayed_jobs)).to include(:delayed_jobs_reserve_where)

    test_up_migration_idempotency
    expect(db.indexes(:delayed_jobs)).to include(:delayed_jobs_reserve_where)

    expect { revert_migration }.not_to raise_error
    expect(db.indexes(:delayed_jobs)).to include(:delayed_jobs_reserve)

    test_down_migration_idempotency
    expect(db.indexes(:delayed_jobs)).to include(:delayed_jobs_reserve)
  end
end
