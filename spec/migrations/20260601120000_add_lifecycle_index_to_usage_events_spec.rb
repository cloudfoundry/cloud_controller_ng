require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add the lifecycle index to the usage event tables', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260601120000_add_lifecycle_index_to_usage_events.rb' }
  end

  let(:run_migration) do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
  end

  let(:revert_migration) do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)
  end

  it 'adds the lifecycle index to both usage event tables (idempotently) and removes it on revert' do
    # Before migration: the lifecycle indexes should not exist.
    expect(db.indexes(:app_usage_events)).not_to include(:app_usage_events_lifecycle_index)
    expect(db.indexes(:service_usage_events)).not_to include(:service_usage_events_lifecycle_index)

    # Up migration adds both indexes with the expected column order.
    expect { run_migration }.not_to raise_error
    expect(db.indexes(:app_usage_events)).to include(:app_usage_events_lifecycle_index)
    expect(db.indexes(:service_usage_events)).to include(:service_usage_events_lifecycle_index)
    expect(db.indexes(:app_usage_events)[:app_usage_events_lifecycle_index][:columns]).to eq(%i[state app_guid id])
    expect(db.indexes(:service_usage_events)[:service_usage_events_lifecycle_index][:columns]).to eq(%i[state service_instance_guid id])

    # Up migration is idempotent: running again does not fail.
    expect { run_migration }.not_to raise_error
    expect(db.indexes(:app_usage_events)).to include(:app_usage_events_lifecycle_index)
    expect(db.indexes(:service_usage_events)).to include(:service_usage_events_lifecycle_index)

    # Down migration removes both indexes.
    expect { revert_migration }.not_to raise_error
    expect(db.indexes(:app_usage_events)).not_to include(:app_usage_events_lifecycle_index)
    expect(db.indexes(:service_usage_events)).not_to include(:service_usage_events_lifecycle_index)

    # Down migration is idempotent: running again does not fail.
    expect { revert_migration }.not_to raise_error
    expect(db.indexes(:app_usage_events)).not_to include(:app_usage_events_lifecycle_index)
    expect(db.indexes(:service_usage_events)).not_to include(:service_usage_events_lifecycle_index)
  end
end
