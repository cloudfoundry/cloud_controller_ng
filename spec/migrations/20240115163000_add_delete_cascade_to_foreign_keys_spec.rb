require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add delete cascade to foreign keys', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240115163000_add_delete_cascade_to_foreign_keys.rb' }
  end

  describe 'buildpack_lifecycle_data table' do
    after do
      db[:buildpack_lifecycle_data].delete
      db[:builds].delete
    end

    it 'adds foreign key constraint and deletes orphaned entries' do
      # Before migration: allows inserts with non-existent build_guid
      expect { db[:buildpack_lifecycle_data].insert(guid: 'bld_guid_test', build_guid: 'not_exists') }.not_to raise_error
      db[:buildpack_lifecycle_data].delete

      # Setup test data
      db[:builds].insert(guid: 'build_guid')
      db[:buildpack_lifecycle_data].insert(guid: 'bld_guid', build_guid: 'build_guid')
      db[:buildpack_lifecycle_buildpacks].insert(guid: 'blb_guid', buildpack_lifecycle_data_guid: 'bld_guid')
      db[:buildpack_lifecycle_data].insert(guid: 'another_bld_guid', build_guid: 'not_exists')
      db[:buildpack_lifecycle_buildpacks].insert(guid: 'another_blb_guid', buildpack_lifecycle_data_guid: 'another_bld_guid')

      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

      # After migration: prevents inserts with non-existent build_guid
      expect { db[:buildpack_lifecycle_data].insert(guid: 'bld_guid_new', build_guid: 'not_exists') }.to raise_error(Sequel::ForeignKeyConstraintViolation)

      # After migration: orphaned entries deleted, valid ones kept
      expect(db[:buildpack_lifecycle_data].where(guid: 'bld_guid').count).to eq(1)
      expect(db[:buildpack_lifecycle_buildpacks].where(guid: 'blb_guid').count).to eq(1)
      expect(db[:buildpack_lifecycle_data].where(guid: 'another_bld_guid').count).to eq(0)
      expect(db[:buildpack_lifecycle_buildpacks].where(guid: 'another_blb_guid').count).to eq(0)
    end
  end
end
