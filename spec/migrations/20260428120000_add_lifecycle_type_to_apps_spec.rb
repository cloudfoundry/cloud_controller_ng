require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add lifecycle_type to apps', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260428120000_add_lifecycle_type_to_apps.rb' }
  end

  it 'adds and removes the lifecycle_type column and index (idempotent)' do
    expect(db.schema(:apps).map(&:first)).not_to include(:lifecycle_type)
    expect(db.indexes(:apps)).not_to have_key(:apps_lifecycle_type_index)

    # up
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    expect(db.schema(:apps).map(&:first)).to include(:lifecycle_type)
    expect(db.indexes(:apps)).to have_key(:apps_lifecycle_type_index)
    expect(db.indexes(:apps)[:apps_lifecycle_type_index][:columns]).to eq([:lifecycle_type])

    lifecycle_type_column = db.schema(:apps).find { |col| col[0] == :lifecycle_type }
    expect(lifecycle_type_column[1][:allow_null]).to be true

    # up is idempotent
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    # down
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)

    expect(db.schema(:apps).map(&:first)).not_to include(:lifecycle_type)
    expect(db.indexes(:apps)).not_to have_key(:apps_lifecycle_type_index)

    # down is idempotent
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
  end
end
