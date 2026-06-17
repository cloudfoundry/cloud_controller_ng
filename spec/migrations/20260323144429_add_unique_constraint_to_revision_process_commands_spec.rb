require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'add unique constraint to revision_process_commands', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260323144429_add_unique_constraint_to_revision_process_commands.rb' }
  end

  let(:app_guid) { SecureRandom.uuid }
  let(:revision_guid) { SecureRandom.uuid }

  it 'removes duplicates, adds constraint and reverts migration' do
    db[:apps].insert(guid: app_guid, name: 'test-app')
    db[:revisions].insert(guid: revision_guid, app_guid: app_guid, description: 'some description')

    # create duplicate entries
    db[:revision_process_commands].insert(guid: SecureRandom.uuid, revision_guid: revision_guid, process_type: 'worker')
    db[:revision_process_commands].insert(guid: SecureRandom.uuid, revision_guid: revision_guid, process_type: 'worker')
    expect(db[:revision_process_commands].where(revision_guid: revision_guid, process_type: 'worker').count).to eq(2)

    # run the migration
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    # verify duplicates are removed and constraint is enforced
    expect(db[:revision_process_commands].where(revision_guid: revision_guid, process_type: 'worker').count).to eq(1)
    expect(db.indexes(:revision_process_commands)).to include(:revision_process_commands_revision_guid_process_type_index)
    expect do
      db[:revision_process_commands].insert(guid: SecureRandom.uuid, revision_guid: revision_guid, process_type: 'worker')
    end.to raise_error(Sequel::UniqueConstraintViolation)

    # running the migration again should not cause any errors
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    # roll back the migration
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)

    # verify constraint is removed and duplicates can be re-inserted
    expect(db.indexes(:revision_process_commands)).not_to include(:revision_process_commands_revision_guid_process_type_index)
    expect do
      db[:revision_process_commands].insert(guid: SecureRandom.uuid, revision_guid: revision_guid, process_type: 'worker')
    end.not_to raise_error
  end
end
