require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'add unique constraint to sidecar process types', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20251030100000_add_unique_constraint_to_sidecar_process_types.rb' }
  end

  let(:app_guid) { SecureRandom.uuid }
  let(:sidecar_guid) { SecureRandom.uuid }
  let(:revision_guid) { SecureRandom.uuid }
  let(:revision_sidecar_guid) { SecureRandom.uuid }

  it 'removes duplicates, adds unique constraints, and is reversible' do
    db[:apps].insert(guid: app_guid, name: 'test-app')
    db[:sidecars].insert(guid: sidecar_guid, name: 'test-sidecar', command: 'command', app_guid: app_guid)
    db[:revisions].insert(guid: revision_guid, app_guid: app_guid, description: 'some description')
    db[:revision_sidecars].insert(guid: revision_sidecar_guid, name: 'test-sidecar', command: 'command', revision_guid: revision_guid)

    # =========================================================================================
    # SETUP: Create duplicate entries for both tables to test the de-duplication logic.
    # =========================================================================================
    db[:sidecar_process_types].insert(sidecar_guid: sidecar_guid, type: 'web', app_guid: app_guid, guid: SecureRandom.uuid)
    db[:sidecar_process_types].insert(sidecar_guid: sidecar_guid, type: 'web', app_guid: app_guid, guid: SecureRandom.uuid)
    expect(db[:sidecar_process_types].where(sidecar_guid: sidecar_guid, type: 'web').count).to eq(2)

    db[:revision_sidecar_process_types].insert(revision_sidecar_guid: revision_sidecar_guid, type: 'worker', guid: SecureRandom.uuid)
    db[:revision_sidecar_process_types].insert(revision_sidecar_guid: revision_sidecar_guid, type: 'worker', guid: SecureRandom.uuid)
    expect(db[:revision_sidecar_process_types].where(revision_sidecar_guid: revision_sidecar_guid, type: 'worker').count).to eq(2)

    # =========================================================================================
    # UP MIGRATION: Run the migration to apply the unique constraints.
    # =========================================================================================
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    # =========================================================================================
    # ASSERT UP MIGRATION: Verify that duplicates are removed and constraints are enforced.
    # =========================================================================================
    expect(db[:sidecar_process_types].where(sidecar_guid: sidecar_guid, type: 'web').count).to eq(1)
    expect(db.indexes(:sidecar_process_types)).to include(:sidecar_process_types_sidecar_guid_type_index)
    expect { db[:sidecar_process_types].insert(sidecar_guid: sidecar_guid, type: 'web', app_guid: app_guid, guid: SecureRandom.uuid) }.to raise_error(Sequel::UniqueConstraintViolation)

    expect(db[:revision_sidecar_process_types].where(revision_sidecar_guid: revision_sidecar_guid, type: 'worker').count).to eq(1)
    expect(db.indexes(:revision_sidecar_process_types)).to include(:revision_sidecar_process_types_revision_sidecar_guid_type_index)
    expect { db[:revision_sidecar_process_types].insert(revision_sidecar_guid: revision_sidecar_guid, type: 'worker', guid: SecureRandom.uuid) }.to raise_error(Sequel::UniqueConstraintViolation)

    # =========================================================================================
    # TEST IDEMPOTENCY: Running the migration again should not cause any errors.
    # =========================================================================================
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    # =========================================================================================
    # DOWN MIGRATION: Roll back the migration to remove the constraints.
    # =========================================================================================
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)

    # =========================================================================================
    # ASSERT DOWN MIGRATION: Verify that constraints are removed and duplicates can be re-inserted.
    # =========================================================================================
    expect(db.indexes(:sidecar_process_types)).not_to include(:sidecar_process_types_sidecar_guid_type_index)
    expect { db[:sidecar_process_types].insert(sidecar_guid: sidecar_guid, type: 'web', app_guid: app_guid, guid: SecureRandom.uuid) }.not_to raise_error

    expect(db.indexes(:revision_sidecar_process_types)).not_to include(:revision_sidecar_process_types_revision_sidecar_guid_type_index)
    expect { db[:revision_sidecar_process_types].insert(revision_sidecar_guid: revision_sidecar_guid, type: 'worker', guid: SecureRandom.uuid) }.not_to raise_error
  end
end
