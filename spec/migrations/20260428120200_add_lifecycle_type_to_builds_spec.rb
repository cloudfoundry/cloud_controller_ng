require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add lifecycle_type to builds', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260428120200_add_lifecycle_type_to_builds.rb' }
  end

  it 'adds and removes the lifecycle_type column and index (idempotent)' do
    expect(db.schema(:builds).map(&:first)).not_to include(:lifecycle_type)
    expect(db.indexes(:builds)).not_to have_key(:builds_lifecycle_type_index)

    # up
    run_migration

    expect(db.schema(:builds).map(&:first)).to include(:lifecycle_type)
    expect(db.indexes(:builds)).to have_key(:builds_lifecycle_type_index)
    expect(db.indexes(:builds)[:builds_lifecycle_type_index][:columns]).to eq([:lifecycle_type])

    lifecycle_type_column = db.schema(:builds).find { |col| col[0] == :lifecycle_type }
    expect(lifecycle_type_column[1][:allow_null]).to be true

    # up is idempotent
    test_up_migration_idempotency

    # down
    revert_migration

    expect(db.schema(:builds).map(&:first)).not_to include(:lifecycle_type)
    expect(db.indexes(:builds)).not_to have_key(:builds_lifecycle_type_index)

    # down is idempotent
    test_down_migration_idempotency
  end
end
