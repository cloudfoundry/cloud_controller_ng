require 'spec_helper'
require 'migrations/helpers/migration_shared_context'
RSpec.describe 'add unique constraint to revision sidecar types', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260320141005_add_unique_constraint_to_revision_sidecars.rb' }
  end

  let(:app_guid) { SecureRandom.uuid }
  let(:revision_guid) { SecureRandom.uuid }

  it 'remove duplicates, add constraint and revert migration' do
    db[:apps].insert(guid: app_guid, name: 'test-app')
    db[:revisions].insert(guid: revision_guid, app_guid: app_guid, description: 'some description')

    # create duplicate entries
    db[:revision_sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', revision_guid: revision_guid)
    db[:revision_sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', revision_guid: revision_guid)
    expect(db[:revision_sidecars].where(name: 'app', revision_guid: revision_guid).count).to eq(2)

    # run the migration
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    # verify duplicates are removed and constraint is enforced
    expect(db[:revision_sidecars].where(name: 'app', revision_guid: revision_guid).count).to eq(1)
    expect(db.indexes(:revision_sidecars)).to include(:revision_sidecars_revision_guid_name_index)
    expect { db[:revision_sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', revision_guid: revision_guid) }.to raise_error(Sequel::UniqueConstraintViolation)

    # running the migration again should not cause any errors
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    # roll back the migration
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)

    # verify constraint is removed and duplicates can be re-inserted
    expect(db.indexes(:revision_sidecars)).not_to include(:revision_sidecars_revision_guid_name_index)
    expect { db[:revision_sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', revision_guid: revision_guid) }.not_to raise_error
  end
end
