require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'add unique constraint to buildpacks', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260318083940_add_unique_constraint_to_buildpacks.rb' }
  end

  describe 'buildpacks table' do
    it 'removes duplicates, swaps indexes, and handles idempotency' do
      # Drop old unique index so we can insert duplicates
      db.alter_table(:buildpacks) { drop_index %i[name stack], name: :unique_name_and_stack }

      surviving_guid = SecureRandom.uuid
      duplicate_guid = SecureRandom.uuid

      db[:buildpacks].insert(guid: surviving_guid, name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 1)
      db[:buildpacks].insert(guid: duplicate_guid, name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 2)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'cnb', position: 3)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'ruby', stack: 'cflinuxfs4', lifecycle: 'buildpack', position: 4)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'go', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 5)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'go', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 6)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'go', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 7)

      expect(db[:buildpacks].where(name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'buildpack').count).to eq(2)
      expect(db[:buildpacks].where(name: 'go', stack: 'cflinuxfs3', lifecycle: 'buildpack').count).to eq(3)

      # add annotations and labels referencing the duplicate buildpack
      db[:buildpack_annotations].insert(guid: SecureRandom.uuid, resource_guid: surviving_guid, key_name: 'env', value: 'prod')
      db[:buildpack_annotations].insert(guid: SecureRandom.uuid, resource_guid: duplicate_guid, key_name: 'env', value: 'staging')
      db[:buildpack_labels].insert(guid: SecureRandom.uuid, resource_guid: surviving_guid, key_name: 'team', value: 'a')
      db[:buildpack_labels].insert(guid: SecureRandom.uuid, resource_guid: duplicate_guid, key_name: 'team', value: 'b')

      # run the migration
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

      # Verify duplicates are removed, keeping one per (name, stack, lifecycle)
      expect(db[:buildpacks].where(name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'buildpack').count).to eq(1)
      expect(db[:buildpacks].where(name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'cnb').count).to eq(1)
      expect(db[:buildpacks].where(name: 'ruby', stack: 'cflinuxfs4', lifecycle: 'buildpack').count).to eq(1)
      expect(db[:buildpacks].where(name: 'go', stack: 'cflinuxfs3', lifecycle: 'buildpack').count).to eq(1)

      # verify annotations and labels for the duplicate are removed, surviving buildpack intact
      expect(db[:buildpack_annotations].where(resource_guid: duplicate_guid).count).to eq(0)
      expect(db[:buildpack_labels].where(resource_guid: duplicate_guid).count).to eq(0)
      expect(db[:buildpack_annotations].where(resource_guid: surviving_guid).count).to eq(1)
      expect(db[:buildpack_labels].where(resource_guid: surviving_guid).count).to eq(1)

      # Verify old index is dropped and new index is added
      expect(db.indexes(:buildpacks)).not_to include(:unique_name_and_stack)
      expect(db.indexes(:buildpacks)).to include(:buildpacks_name_stack_lifecycle_index)

      # Test up migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # First remove test data that would conflict with the old (name, stack) unique index
      db[:buildpack_annotations].delete
      db[:buildpack_labels].delete
      db[:buildpacks].delete

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error

      # Verify new index is dropped and old index is restored
      expect(db.indexes(:buildpacks)).not_to include(:buildpacks_name_stack_lifecycle_index)
      expect(db.indexes(:buildpacks)).to include(:unique_name_and_stack)

      # Verify the restored index enforces uniqueness on (name, stack)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 1)
      expect do
        db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'cnb', position: 2)
      end.to raise_error(Sequel::UniqueConstraintViolation)
      db[:buildpacks].delete

      # Test down migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:buildpacks)).not_to include(:buildpacks_name_stack_lifecycle_index)
    end
  end
end
