require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to allow multiple service bindings', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250731071027_allow_multiple_service_bindings.rb' }
  end

  describe 'service_bindings table' do
    context 'up migration' do
      it 'is in the correct state before migration' do
        expect(db.indexes(:service_bindings)).to include(:unique_service_binding_service_instance_guid_app_guid)
        expect(db.indexes(:service_bindings)).to include(:unique_service_binding_app_guid_name)
        expect(db.indexes(:service_bindings)).not_to include(:service_bindings_app_guid_service_instance_guid_index)
        expect(db.indexes(:service_bindings)).not_to include(:service_bindings_app_guid_name_index)
      end

      it 'migrates successfully' do
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:service_bindings)).not_to include(:unique_service_binding_app_guid_name)
        expect(db.indexes(:service_bindings)).not_to include(:unique_service_binding_service_instance_guid_app_guid)
        expect(db.indexes(:service_bindings)).to include(:service_bindings_app_guid_service_instance_guid_index)
        expect(db.indexes(:service_bindings)).to include(:service_bindings_app_guid_name_index)
      end

      it 'does not fail if indexes/constraints are already in desired state' do
        db.alter_table :service_bindings do
          drop_constraint :unique_service_binding_service_instance_guid_app_guid
          drop_constraint :unique_service_binding_app_guid_name
        end
        if db.database_type == :postgres
          db.add_index :service_bindings, %i[app_guid service_instance_guid], name: :service_bindings_app_guid_service_instance_guid_index, if_not_exists: true, concurrently: true
          db.add_index :service_bindings, %i[app_guid name], name: :service_bindings_app_guid_name_index, if_not_exists: true, concurrently: true
        else
          db.add_index :service_bindings, %i[app_guid service_instance_guid], name: :service_bindings_app_guid_service_instance_guid_index, if_not_exists: true
          db.add_index :service_bindings, %i[app_guid name], name: :service_bindings_app_guid_name_index, if_not_exists: true
        end
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      end
    end

    context 'down migration' do
      it 'rolls back successfully' do
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:service_bindings)).to include(:unique_service_binding_service_instance_guid_app_guid)
        expect(db.indexes(:service_bindings)).to include(:unique_service_binding_app_guid_name)
        expect(db.indexes(:service_bindings)).not_to include(:service_bindings_app_guid_service_instance_guid_index)
        expect(db.indexes(:service_bindings)).not_to include(:service_bindings_app_guid_name_index)
      end

      it 'does not fail if indexes/constraints are already in desired state' do
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        db.alter_table :service_bindings do
          add_unique_constraint %i[service_instance_guid app_guid], name: :unique_service_binding_service_instance_guid_app_guid
          add_unique_constraint %i[app_guid name], name: :unique_service_binding_app_guid_name
        end
        if db.database_type == :postgres
          db.drop_index :service_bindings, %i[app_guid service_instance_guid], name: :service_bindings_app_guid_service_instance_guid_index, if_exists: true, concurrently: true
          db.drop_index :service_bindings, %i[app_guid name], name: :service_bindings_app_guid_name_index, if_exists: true, concurrently: true
        else
          db.drop_index :service_bindings, %i[app_guid service_instance_guid], name: :service_bindings_app_guid_service_instance_guid_index, if_exists: true
          db.drop_index :service_bindings, %i[app_guid name], name: :service_bindings_app_guid_name_index, if_exists: true
        end

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      end
    end
  end
end
