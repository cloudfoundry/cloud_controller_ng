require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'security groups spaces unique index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20251016120006_security_groups_spaces_unique_index_spec.rb' }
  end

  let(:space_1) { VCAP::CloudController::Space.make }
  let(:space_2) { VCAP::CloudController::Space.make }
  let(:sec_group_1) { VCAP::CloudController::SecurityGroup.make }
  let(:sec_group_2) { VCAP::CloudController::SecurityGroup.make }

  describe 'security_groups_spaces table' do
    context 'up migration' do
      it 'removes duplicates, updates indexes, and handles idempotency' do
        # Verify initial state
        expect(db.indexes(:security_groups_spaces)).to include(:sgs_spaces_ids)
        expect(db.indexes(:security_groups_spaces)).not_to include(:security_groups_spaces_ids)

        # Insert test data with duplicates
        db[:security_groups_spaces].insert(security_group_id: sec_group_1.id, space_id: space_1.id)
        db[:security_groups_spaces].insert(security_group_id: sec_group_1.id, space_id: space_1.id)
        db[:security_groups_spaces].insert(security_group_id: sec_group_1.id, space_id: space_2.id)
        db[:security_groups_spaces].insert(security_group_id: sec_group_2.id, space_id: space_1.id)
        db[:security_groups_spaces].insert(security_group_id: sec_group_2.id, space_id: space_2.id)
        db[:security_groups_spaces].insert(security_group_id: sec_group_2.id, space_id: space_2.id)
        db[:security_groups_spaces].insert(security_group_id: sec_group_2.id, space_id: space_2.id)

        # Count duplicates before migration
        expect(db[:security_groups_spaces].where(security_group_id: sec_group_1.id, space_id: space_1.id).count).to eq(2)
        expect(db[:security_groups_spaces].where(security_group_id: sec_group_1.id, space_id: space_2.id).count).to eq(1)
        expect(db[:security_groups_spaces].where(security_group_id: sec_group_2.id, space_id: space_1.id).count).to eq(1)
        expect(db[:security_groups_spaces].where(security_group_id: sec_group_2.id, space_id: space_2.id).count).to eq(3)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

        # Verify duplicates are removed after migration
        expect(db[:security_groups_spaces].where(security_group_id: sec_group_1.id, space_id: space_1.id).count).to eq(1)
        expect(db[:security_groups_spaces].where(security_group_id: sec_group_1.id, space_id: space_2.id).count).to eq(1)
        expect(db[:security_groups_spaces].where(security_group_id: sec_group_2.id, space_id: space_1.id).count).to eq(1)
        expect(db[:security_groups_spaces].where(security_group_id: sec_group_2.id, space_id: space_2.id).count).to eq(1)

        # Verify indexes are updated
        expect(db.indexes(:security_groups_spaces)).not_to include(:sgs_spaces_ids)
        expect(db.indexes(:security_groups_spaces)).to include(:security_groups_spaces_ids)

        # Test idempotency: running again should not fail
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      end
    end

    context 'down migration' do
      it 'rolls back successfully and handles idempotency' do
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:security_groups_spaces)).to include(:sgs_spaces_ids)
        expect(db.indexes(:security_groups_spaces)).not_to include(:security_groups_spaces_ids)

        # Test idempotency: running rollback again should not fail
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      end
    end
  end
end
