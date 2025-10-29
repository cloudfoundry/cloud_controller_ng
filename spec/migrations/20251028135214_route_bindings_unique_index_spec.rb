require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'route bindings unique index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20251028135214_route_bindings_unique_index.rb' }
  end

  let(:space) { VCAP::CloudController::Space.make }
  let(:service_instance_1) { VCAP::CloudController::ServiceInstance.make(space:) }
  let(:service_instance_2) { VCAP::CloudController::ServiceInstance.make(space:) }
  let(:route_1) { VCAP::CloudController::Route.make(space:) }
  let(:route_2) { VCAP::CloudController::Route.make(space:) }

  describe 'route_bindings table' do
    context 'up migration' do
      it 'is in the correct state before migration' do
        expect(db.indexes(:route_bindings)).not_to include(:route_bindings_route_id_service_instance_id_index)
      end

      it 'removes duplicates and migrates successfully by adding unique index' do
        db[:route_bindings].insert(route_id: route_1.id, service_instance_id: service_instance_1.id, guid: SecureRandom.uuid)
        db[:route_bindings].insert(route_id: route_1.id, service_instance_id: service_instance_1.id, guid: SecureRandom.uuid)
        db[:route_bindings].insert(route_id: route_2.id, service_instance_id: service_instance_1.id, guid: SecureRandom.uuid)
        db[:route_bindings].insert(route_id: route_1.id, service_instance_id: service_instance_2.id, guid: SecureRandom.uuid)
        db[:route_bindings].insert(route_id: route_2.id, service_instance_id: service_instance_2.id, guid: SecureRandom.uuid)
        db[:route_bindings].insert(route_id: route_2.id, service_instance_id: service_instance_2.id, guid: SecureRandom.uuid)
        db[:route_bindings].insert(route_id: route_2.id, service_instance_id: service_instance_2.id, guid: SecureRandom.uuid)

        # Count duplicates before migration
        expect(db[:route_bindings].where(service_instance_id: service_instance_1.id, route_id: route_1.id).count).to eq(2)
        expect(db[:route_bindings].where(service_instance_id: service_instance_1.id, route_id: route_2.id).count).to eq(1)
        expect(db[:route_bindings].where(service_instance_id: service_instance_2.id, route_id: route_1.id).count).to eq(1)
        expect(db[:route_bindings].where(service_instance_id: service_instance_2.id, route_id: route_2.id).count).to eq(3)

        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

        # Verify duplicates are removed after migration
        expect(db[:route_bindings].where(service_instance_id: service_instance_1.id, route_id: route_1.id).count).to eq(1)
        expect(db[:route_bindings].where(service_instance_id: service_instance_1.id, route_id: route_2.id).count).to eq(1)
        expect(db[:route_bindings].where(service_instance_id: service_instance_2.id, route_id: route_1.id).count).to eq(1)
        expect(db[:route_bindings].where(service_instance_id: service_instance_2.id, route_id: route_2.id).count).to eq(1)

        # Verify index is added
        expect(db.indexes(:route_bindings)).to include(:route_bindings_route_id_service_instance_id_index)
      end

      it 'does not fail if indexes/constraints are already in desired state' do
        db.alter_table(:route_bindings) { add_index %i[route_id service_instance_id], unique: true, name: :route_bindings_route_id_service_instance_id_index }
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      end
    end

    context 'down migration' do
      it 'rolls back successfully' do
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:route_bindings)).not_to include(:route_bindings_route_id_service_instance_id_index)
        expect(db.indexes(:route_bindings)).to include(:route_id) if db.database_type == :mysql
      end

      it 'does not fail if indexes/constraints are already in desired state' do
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        db.alter_table(:route_bindings) { drop_index %i[route_id service_instance_id], unique: true, name: :route_bindings_route_id_service_instance_id_index }
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      end
    end
  end
end
