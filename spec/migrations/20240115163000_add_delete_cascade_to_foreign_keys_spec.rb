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

    context 'before adding the foreign key' do
      it 'allows inserts with a build_guid that does not exist' do
        expect { db[:buildpack_lifecycle_data].insert(guid: 'bld_guid', build_guid: 'not_exists') }.not_to raise_error
      end
    end

    context 'after adding the foreign key' do
      it 'prevents inserts with a build_guid that does not exist' do
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

        expect { db[:buildpack_lifecycle_data].insert(guid: 'bld_guid', build_guid: 'not_exists') }.to raise_error(Sequel::ForeignKeyConstraintViolation)
      end

      it 'deleted orphaned buildpack_lifecycle_data entries but kept valid ones' do
        db[:builds].insert(guid: 'build_guid')
        db[:buildpack_lifecycle_data].insert(guid: 'bld_guid', build_guid: 'build_guid')
        db[:buildpack_lifecycle_data].insert(guid: 'another_bld_guid', build_guid: 'not_exists')

        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

        expect(db[:buildpack_lifecycle_data].where(guid: 'bld_guid').count).to eq(1)
        expect(db[:buildpack_lifecycle_data].where(guid: 'another_bld_guid').count).to eq(0)
      end
    end
  end
end
