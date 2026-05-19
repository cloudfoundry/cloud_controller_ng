require 'spec_helper'
require 'migrations/helpers/migration_shared_context'
RSpec.describe 'add unique constraint to sidecars', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260323092954_add_unique_constraint_to_sidecars.rb' }
  end

  let(:app_guid) { SecureRandom.uuid }

  it 'remove duplicates, add constraint and revert migration' do
    db[:apps].insert(guid: app_guid, name: 'test-app')

    # create duplicate entries
    db[:sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', app_guid: app_guid)
    db[:sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', app_guid: app_guid)
    expect(db[:sidecars].where(name: 'app', app_guid: app_guid).count).to eq(2)

    # run the migration
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    # verify duplicates are removed and constraint is enforced
    expect(db[:sidecars].where(name: 'app', app_guid: app_guid).count).to eq(1)
    expect(db.indexes(:sidecars)).to include(:sidecars_app_guid_name_index)
    expect { db[:sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', app_guid: app_guid) }.to raise_error(Sequel::UniqueConstraintViolation)

    # running the migration again should not cause any errors
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    # roll back the migration
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)

    # verify constraint is removed and duplicates can be re-inserted
    expect(db.indexes(:sidecars)).not_to include(:sidecars_app_guid_name_index)
    expect { db[:sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', app_guid: app_guid) }.not_to raise_error
  end
end
