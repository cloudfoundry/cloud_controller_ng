require 'migration_spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add broker_provided_metadata column to service_instances table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20251121174647_add_broker_provided_metadata_to_service_instances.rb' }
  end

  describe 'service_instances table' do
    let(:quota_def_id) do
      db[:quota_definitions].insert(guid: SecureRandom.uuid, name: "quota-#{SecureRandom.uuid}", non_basic_services_allowed: false, total_services: -1, memory_limit: 0,
                                    total_routes: -1, created_at: Time.now.utc, updated_at: Time.now.utc)
    end
    let(:org_id) do
      db[:organizations].insert(guid: SecureRandom.uuid, name: "org-#{SecureRandom.uuid}", quota_definition_id: quota_def_id, created_at: Time.now.utc, updated_at: Time.now.utc)
    end
    let(:space_id) { db[:spaces].insert(guid: SecureRandom.uuid, name: "space-#{SecureRandom.uuid}", organization_id: org_id, created_at: Time.now.utc, updated_at: Time.now.utc) }

    it 'adds broker_provided_metadata column with correct properties' do
      db[:service_instances].insert(
        guid: 'existing-service-instance-guid',
        name: 'existing-instance',
        space_id: space_id,
        created_at: Time.now.utc,
        updated_at: Time.now.utc
      )

      expect(db[:service_instances].columns).not_to include(:broker_provided_metadata)

      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

      expect(db[:service_instances].columns).to include(:broker_provided_metadata)

      existing_instance = db[:service_instances].first(guid: 'existing-service-instance-guid')
      expect(existing_instance).not_to be_nil
      expect(existing_instance[:broker_provided_metadata]).to be_nil

      db[:service_instances].insert(
        guid: 'test-service-instance-guid',
        name: 'test-instance',
        space_id: space_id,
        broker_provided_metadata: nil,
        created_at: Time.now.utc,
        updated_at: Time.now.utc
      )
      instance_with_null = db[:service_instances].first(guid: 'test-service-instance-guid')
      expect(instance_with_null[:broker_provided_metadata]).to be_nil

      metadata_json = '{"labels": {"version": "1.0"}, "attributes": {"engine": "postgresql"}}'
      db[:service_instances].insert(
        guid: 'test-service-instance-with-metadata',
        name: 'test-instance-with-metadata',
        space_id: space_id,
        broker_provided_metadata: metadata_json,
        created_at: Time.now.utc,
        updated_at: Time.now.utc
      )
      instance_with_metadata = db[:service_instances].first(guid: 'test-service-instance-with-metadata')
      expect(instance_with_metadata[:broker_provided_metadata]).to eq(metadata_json)
    end
  end
end
