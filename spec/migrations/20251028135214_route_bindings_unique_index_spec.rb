require 'migration_spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'route bindings unique index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20251028135214_route_bindings_unique_index.rb' }
  end

  let(:quota_def_id) do
    db[:quota_definitions].insert(guid: SecureRandom.uuid, name: "quota-#{SecureRandom.uuid}", non_basic_services_allowed: false, total_services: -1, memory_limit: 0,
                                  total_routes: -1)
  end
  let(:org_id) { db[:organizations].insert(guid: SecureRandom.uuid, name: "org-#{SecureRandom.uuid}", quota_definition_id: quota_def_id) }
  let(:space_id) { db[:spaces].insert(guid: SecureRandom.uuid, name: "space-#{SecureRandom.uuid}", organization_id: org_id) }
  let(:domain_id) { db[:domains].insert(guid: SecureRandom.uuid, name: "domain-#{SecureRandom.uuid}.example.com") }
  let(:service_instance_1_id) { db[:service_instances].insert(guid: SecureRandom.uuid, name: "si1-#{SecureRandom.uuid}", space_id: space_id) }
  let(:service_instance_2_id) { db[:service_instances].insert(guid: SecureRandom.uuid, name: "si2-#{SecureRandom.uuid}", space_id: space_id) }
  let(:route_1_id) { db[:routes].insert(guid: SecureRandom.uuid, host: 'r1', domain_id: domain_id, space_id: space_id) }
  let(:route_2_id) { db[:routes].insert(guid: SecureRandom.uuid, host: 'r2', domain_id: domain_id, space_id: space_id) }

  describe 'route_bindings table' do
    it 'removes duplicates, manages unique index, and handles idempotency' do
      # Verify initial state
      expect(db.indexes(:route_bindings)).not_to include(:route_bindings_route_id_service_instance_id_index)

      # Insert test data with duplicates
      db[:route_bindings].insert(route_id: route_1_id, service_instance_id: service_instance_1_id, guid: SecureRandom.uuid)
      db[:route_bindings].insert(route_id: route_1_id, service_instance_id: service_instance_1_id, guid: SecureRandom.uuid)
      db[:route_bindings].insert(route_id: route_2_id, service_instance_id: service_instance_1_id, guid: SecureRandom.uuid)
      db[:route_bindings].insert(route_id: route_1_id, service_instance_id: service_instance_2_id, guid: SecureRandom.uuid)
      db[:route_bindings].insert(route_id: route_2_id, service_instance_id: service_instance_2_id, guid: SecureRandom.uuid)
      db[:route_bindings].insert(route_id: route_2_id, service_instance_id: service_instance_2_id, guid: SecureRandom.uuid)
      db[:route_bindings].insert(route_id: route_2_id, service_instance_id: service_instance_2_id, guid: SecureRandom.uuid)

      # Count duplicates before migration
      expect(db[:route_bindings].where(service_instance_id: service_instance_1_id, route_id: route_1_id).count).to eq(2)
      expect(db[:route_bindings].where(service_instance_id: service_instance_1_id, route_id: route_2_id).count).to eq(1)
      expect(db[:route_bindings].where(service_instance_id: service_instance_2_id, route_id: route_1_id).count).to eq(1)
      expect(db[:route_bindings].where(service_instance_id: service_instance_2_id, route_id: route_2_id).count).to eq(3)

      # === UP MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # Verify duplicates are removed after migration
      expect(db[:route_bindings].where(service_instance_id: service_instance_1_id, route_id: route_1_id).count).to eq(1)
      expect(db[:route_bindings].where(service_instance_id: service_instance_1_id, route_id: route_2_id).count).to eq(1)
      expect(db[:route_bindings].where(service_instance_id: service_instance_2_id, route_id: route_1_id).count).to eq(1)
      expect(db[:route_bindings].where(service_instance_id: service_instance_2_id, route_id: route_2_id).count).to eq(1)

      # Verify index is added
      expect(db.indexes(:route_bindings)).to include(:route_bindings_route_id_service_instance_id_index)

      # Test up migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:route_bindings)).to include(:route_bindings_route_id_service_instance_id_index)

      # === DOWN MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:route_bindings)).not_to include(:route_bindings_route_id_service_instance_id_index)
      expect(db.indexes(:route_bindings)).to include(:route_id) if db.database_type == :mysql

      # Test down migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:route_bindings)).not_to include(:route_bindings_route_id_service_instance_id_index)
    end
  end
end
