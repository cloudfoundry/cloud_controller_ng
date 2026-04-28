require 'spec_helper'
require 'migrations/helpers/migration_shared_context'
RSpec.describe 'add unique constraint to security_groups', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260323130619_add_unique_constraint_to_security_groups.rb' }
  end

  it 'removes duplicates, adds constraint and reverts migration' do
    space = VCAP::CloudController::Space.make

    # create duplicate entries with join table references
    surviving_id = db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1')
    duplicate_id = db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1')
    expect(db[:security_groups].where(name: 'sec1').count).to eq(2)

    # add security_groups_spaces and staging_security_groups_spaces referencing the duplicate security_groups
    db[:security_groups_spaces].insert(security_group_id: surviving_id, space_id: space.id)
    db[:security_groups_spaces].insert(security_group_id: duplicate_id, space_id: space.id)
    db[:staging_security_groups_spaces].insert(staging_security_group_id: surviving_id, staging_space_id: space.id)
    db[:staging_security_groups_spaces].insert(staging_security_group_id: duplicate_id, staging_space_id: space.id)

    # run the migration
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    # verify duplicates and their join table references are removed, surviving group intact
    expect(db[:security_groups].where(name: 'sec1').count).to eq(1)
    expect(db[:security_groups].where(name: 'sec1').first[:id]).to eq(surviving_id)
    expect(db[:security_groups_spaces].where(security_group_id: duplicate_id).count).to eq(0)
    expect(db[:staging_security_groups_spaces].where(staging_security_group_id: duplicate_id).count).to eq(0)
    expect(db[:security_groups_spaces].where(security_group_id: surviving_id, space_id: space.id).count).to eq(1)
    expect(db[:staging_security_groups_spaces].where(staging_security_group_id: surviving_id, staging_space_id: space.id).count).to eq(1)

    # verify constraint is enforced
    expect(db.indexes(:security_groups)).to include(:security_groups_name_index)
    expect { db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1') }.to raise_error(Sequel::UniqueConstraintViolation)

    # running the migration again should not cause any errors
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    # roll back the migration
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)

    # verify constraint is removed and duplicates can be re-inserted
    expect(db.indexes(:security_groups)).not_to include(:security_groups_name_index)
    expect(db.indexes(:security_groups)).to include(:sg_name_index)
    expect { db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1') }.not_to raise_error
  end
end
