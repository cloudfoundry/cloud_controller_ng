require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to change the delayed_jobs_reserve index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240222131500_change_delayed_jobs_reserve_index.rb' }
  end

  def reserve_index_definition
    db[:pg_indexes].where(tablename: 'delayed_jobs', indexname: 'delayed_jobs_reserve').get(:indexdef)
  end

  # The migration body is a no-op on MySQL, so only exercise it on PostgreSQL.
  it 'changes the index and is idempotent' do
    skip if db.database_type != :postgres

    expect(reserve_index_definition).to end_with('(queue, locked_at, locked_by, failed_at, run_at, priority)')

    expect { run_migration }.not_to raise_error
    expect(reserve_index_definition).to end_with('(queue, locked_at, locked_by, failed_at, run_at, priority) WHERE (failed_at IS NULL)')

    test_up_migration_idempotency
    expect(reserve_index_definition).to end_with('(queue, locked_at, locked_by, failed_at, run_at, priority) WHERE (failed_at IS NULL)')

    expect { revert_migration }.not_to raise_error
    expect(reserve_index_definition).to end_with('(queue, locked_at, locked_by, failed_at, run_at, priority)')

    test_down_migration_idempotency
    expect(reserve_index_definition).to end_with('(queue, locked_at, locked_by, failed_at, run_at, priority)')
  end
end
