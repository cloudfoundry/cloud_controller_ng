require 'migration_spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'add unique constraint to security_groups', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260323130619_add_unique_constraint_to_security_groups.rb' }
  end

  let(:quota_def_id) do
    db[:quota_definitions].insert(guid: SecureRandom.uuid, name: "quota-#{SecureRandom.uuid}", non_basic_services_allowed: false, total_services: -1, memory_limit: 0,
                                  total_routes: -1, created_at: Time.now.utc, updated_at: Time.now.utc)
  end
  let(:org_id) do
    db[:organizations].insert(guid: SecureRandom.uuid, name: "org-#{SecureRandom.uuid}", quota_definition_id: quota_def_id, created_at: Time.now.utc, updated_at: Time.now.utc)
  end
  let(:space_id) { db[:spaces].insert(guid: SecureRandom.uuid, name: "space-#{SecureRandom.uuid}", organization_id: org_id, created_at: Time.now.utc, updated_at: Time.now.utc) }

  it 'removes duplicates, adds constraint and reverts migration' do
    now = Time.now.utc
    surviving_id = db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1', rules: '[]', staging_default: false, running_default: false, created_at: now, updated_at: now)
    duplicate_id = db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1', rules: '[]', staging_default: false, running_default: false, created_at: now, updated_at: now)
    expect(db[:security_groups].where(name: 'sec1').count).to eq(2)

    db[:security_groups_spaces].insert(security_group_id: surviving_id, space_id: space_id)
    db[:security_groups_spaces].insert(security_group_id: duplicate_id, space_id: space_id)
    db[:staging_security_groups_spaces].insert(staging_security_group_id: surviving_id, staging_space_id: space_id)
    db[:staging_security_groups_spaces].insert(staging_security_group_id: duplicate_id, staging_space_id: space_id)

    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    expect(db[:security_groups].where(name: 'sec1').count).to eq(1)
    expect(db[:security_groups].where(name: 'sec1').first[:id]).to eq(surviving_id)
    expect(db[:security_groups_spaces].where(security_group_id: duplicate_id).count).to eq(0)
    expect(db[:staging_security_groups_spaces].where(staging_security_group_id: duplicate_id).count).to eq(0)
    expect(db[:security_groups_spaces].where(security_group_id: surviving_id, space_id: space_id).count).to eq(1)
    expect(db[:staging_security_groups_spaces].where(staging_security_group_id: surviving_id, staging_space_id: space_id).count).to eq(1)

    expect(db.indexes(:security_groups)).to include(:security_groups_name_index)
    expect do
      db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1', rules: '[]', staging_default: false, running_default: false, created_at: now,
                                  updated_at: now)
    end.to raise_error(Sequel::UniqueConstraintViolation)

    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)

    expect(db.indexes(:security_groups)).not_to include(:security_groups_name_index)
    expect(db.indexes(:security_groups)).to include(:sg_name_index)
    expect do
      db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1', rules: '[]', staging_default: false, running_default: false, created_at: now,
                                  updated_at: now)
    end.not_to raise_error
  end
end
