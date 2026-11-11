require 'migration_spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add unique index on service_instance_id to service_instance_operations', isolation: :truncation, type: :migration do
  let(:filename) { '20220818142407_add_unique_index_to_service_instance_operations_service_instance_id.rb' }
  let(:tmp_migrations_dir) { Dir.mktmpdir }
  let(:db) { Sequel::Model.db }

  def insert_quota_def
    db[:quota_definitions].insert(guid: SecureRandom.uuid, name: "quota-#{SecureRandom.uuid}",
                                  non_basic_services_allowed: false, total_services: -1, memory_limit: 0, total_routes: -1)
  end

  def insert_space
    org_id = db[:organizations].insert(guid: SecureRandom.uuid, name: "org-#{SecureRandom.uuid}", quota_definition_id: insert_quota_def)
    db[:spaces].insert(guid: SecureRandom.uuid, name: "space-#{SecureRandom.uuid}", organization_id: org_id)
  end

  def insert_service_instance(space_id)
    db[:service_instances].insert(guid: SecureRandom.uuid, name: "si-#{SecureRandom.uuid}", space_id: space_id)
  end

  def insert_operation(service_instance_id: nil, updated_at: Time.now.utc)
    now = Time.now.utc
    db[:service_instance_operations].insert(guid: SecureRandom.uuid, type: 'create', state: 'succeeded',
                                            service_instance_id: service_instance_id, updated_at: updated_at, created_at: now)
  end

  before do
    FileUtils.cp(File.join(DBMigrator::SEQUEL_MIGRATIONS, filename), tmp_migrations_dir)

    # Revert the given migration, i.e. remove the uniqueness constraint.
    Sequel::Migrator.run(db, tmp_migrations_dir, target: 0, allow_missing_migration_files: true)
  end

  it 'removes duplicate service instance operations' do
    space_id = insert_space

    # Two operations that do not reference a service instance (i.e. service_instance_id is nil);
    # none of them should be removed.
    insert_operation
    insert_operation

    # Two operations that each reference a different service instance (the 'normal' situation);
    # none of them should be removed.
    si1_id = insert_service_instance(space_id)
    insert_operation(service_instance_id: si1_id)
    si2_id = insert_service_instance(space_id)
    insert_operation(service_instance_id: si2_id)

    # Three operations that reference the same service instance and have the same 'updated_at' value;
    # the one with the highest 'id' should be kept (o3).
    now = Time.now.utc
    si3_id = insert_service_instance(space_id)
    o1_id = insert_operation(service_instance_id: si3_id, updated_at: now)
    o2_id = insert_operation(service_instance_id: si3_id, updated_at: now)
    insert_operation(service_instance_id: si3_id, updated_at: now)

    # Three operations that reference the same service instance and have different 'updated_at' values;
    # the one with the newest 'updated_at' value should be kept (o5).
    base_time = Time.now.utc
    si4_id = insert_service_instance(space_id)
    o4_id = insert_operation(service_instance_id: si4_id, updated_at: base_time)
    insert_operation(service_instance_id: si4_id, updated_at: base_time + 1)
    o6_id = insert_operation(service_instance_id: si4_id, updated_at: base_time - 1)

    expect(db[:service_instance_operations].count).to eq(10)

    Sequel::Migrator.run(db, tmp_migrations_dir, allow_missing_migration_files: true)

    expect(db[:service_instance_operations].count).to eq(6)
    expect(db[:service_instance_operations].where(id: o1_id)).to be_empty
    expect(db[:service_instance_operations].where(id: o2_id)).to be_empty
    expect(db[:service_instance_operations].where(id: o4_id)).to be_empty
    expect(db[:service_instance_operations].where(id: o6_id)).to be_empty
  end
end
