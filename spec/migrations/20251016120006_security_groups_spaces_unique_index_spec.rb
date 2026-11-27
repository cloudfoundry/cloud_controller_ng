require 'migration_spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'security groups spaces unique index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20251016120006_security_groups_spaces_unique_index.rb' }
  end

  let(:quota_def_id) do
    db[:quota_definitions].insert(guid: SecureRandom.uuid, name: "quota-#{SecureRandom.uuid}", non_basic_services_allowed: false, total_services: -1, memory_limit: 0,
                                  total_routes: -1, created_at: Time.now.utc, updated_at: Time.now.utc)
  end
  let(:org_id) do
    db[:organizations].insert(guid: SecureRandom.uuid, name: "org-#{SecureRandom.uuid}", quota_definition_id: quota_def_id, created_at: Time.now.utc, updated_at: Time.now.utc)
  end
  let(:space_1_id) do
    db[:spaces].insert(guid: SecureRandom.uuid, name: "space-1-#{SecureRandom.uuid}", organization_id: org_id, created_at: Time.now.utc, updated_at: Time.now.utc)
  end
  let(:space_2_id) do
    db[:spaces].insert(guid: SecureRandom.uuid, name: "space-2-#{SecureRandom.uuid}", organization_id: org_id, created_at: Time.now.utc, updated_at: Time.now.utc)
  end
  let(:sec_group_1_id) do
    db[:security_groups].insert(guid: SecureRandom.uuid, name: "sg-1-#{SecureRandom.uuid}", rules: '[]', staging_default: false, running_default: false, created_at: Time.now.utc,
                                updated_at: Time.now.utc)
  end
  let(:sec_group_2_id) do
    db[:security_groups].insert(guid: SecureRandom.uuid, name: "sg-2-#{SecureRandom.uuid}", rules: '[]', staging_default: false, running_default: false, created_at: Time.now.utc,
                                updated_at: Time.now.utc)
  end

  describe 'security_groups_spaces table' do
    it 'removes duplicates, updates indexes, and handles idempotency' do
      # Verify initial state
      expect(db.indexes(:security_groups_spaces)).to include(:sgs_spaces_ids)
      expect(db.indexes(:security_groups_spaces)).not_to include(:security_groups_spaces_ids)

      # Insert test data with duplicates
      db[:security_groups_spaces].insert(security_group_id: sec_group_1_id, space_id: space_1_id)
      db[:security_groups_spaces].insert(security_group_id: sec_group_1_id, space_id: space_1_id)
      db[:security_groups_spaces].insert(security_group_id: sec_group_1_id, space_id: space_2_id)
      db[:security_groups_spaces].insert(security_group_id: sec_group_2_id, space_id: space_1_id)
      db[:security_groups_spaces].insert(security_group_id: sec_group_2_id, space_id: space_2_id)
      db[:security_groups_spaces].insert(security_group_id: sec_group_2_id, space_id: space_2_id)
      db[:security_groups_spaces].insert(security_group_id: sec_group_2_id, space_id: space_2_id)

      # Count duplicates before migration
      expect(db[:security_groups_spaces].where(security_group_id: sec_group_1_id, space_id: space_1_id).count).to eq(2)
      expect(db[:security_groups_spaces].where(security_group_id: sec_group_1_id, space_id: space_2_id).count).to eq(1)
      expect(db[:security_groups_spaces].where(security_group_id: sec_group_2_id, space_id: space_1_id).count).to eq(1)
      expect(db[:security_groups_spaces].where(security_group_id: sec_group_2_id, space_id: space_2_id).count).to eq(3)

      # === UP MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # Verify duplicates are removed after migration
      expect(db[:security_groups_spaces].where(security_group_id: sec_group_1_id, space_id: space_1_id).count).to eq(1)
      expect(db[:security_groups_spaces].where(security_group_id: sec_group_1_id, space_id: space_2_id).count).to eq(1)
      expect(db[:security_groups_spaces].where(security_group_id: sec_group_2_id, space_id: space_1_id).count).to eq(1)
      expect(db[:security_groups_spaces].where(security_group_id: sec_group_2_id, space_id: space_2_id).count).to eq(1)

      # Verify indexes are updated
      expect(db.indexes(:security_groups_spaces)).not_to include(:sgs_spaces_ids)
      expect(db.indexes(:security_groups_spaces)).to include(:security_groups_spaces_ids)

      # Test up migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:security_groups_spaces)).to include(:security_groups_spaces_ids)

      # === DOWN MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:security_groups_spaces)).to include(:sgs_spaces_ids)
      expect(db.indexes(:security_groups_spaces)).not_to include(:security_groups_spaces_ids)

      # Test down migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:security_groups_spaces)).to include(:sgs_spaces_ids)
      expect(db.indexes(:security_groups_spaces)).not_to include(:security_groups_spaces_ids)
    end
  end
end
