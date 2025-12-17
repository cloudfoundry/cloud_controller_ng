# Migration test for adding broker_provided_metadata column to service_instances table
#
# This test verifies that the migration correctly adds the broker_provided_metadata
# column to the service_instances table with the correct properties (text type, nullable).

require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add broker_provided_metadata column to service_instances table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20251121174647_add_broker_provided_metadata_to_service_instances.rb' }
  end

  describe 'service_instances table' do
    subject(:run_migration) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }

    let(:space) { VCAP::CloudController::Space.make }

    it 'adds a column `broker_provided_metadata`' do
      expect(db[:service_instances].columns).not_to include(:broker_provided_metadata)
      run_migration
      expect(db[:service_instances].columns).to include(:broker_provided_metadata)
    end

    it 'allows null values for broker_provided_metadata' do
      run_migration
      # Insert a service instance without broker_provided_metadata
      db[:service_instances].insert(
        guid: 'test-service-instance-guid',
        name: 'test-instance',
        space_id: space.id,
        broker_provided_metadata: nil
      )
      # Verify the insert succeeded and the column is null
      instance = db[:service_instances].first(guid: 'test-service-instance-guid')
      expect(instance[:broker_provided_metadata]).to be_nil
    end

    it 'accepts text values for broker_provided_metadata' do
      run_migration
      # Insert a service instance with broker_provided_metadata
      metadata_json = '{"labels": {"version": "1.0"}, "attributes": {"engine": "postgresql"}}'
      db[:service_instances].insert(
        guid: 'test-service-instance-with-metadata',
        name: 'test-instance-with-metadata',
        space_id: space.id,
        broker_provided_metadata: metadata_json
      )
      # Verify the metadata was stored correctly
      instance = db[:service_instances].first(guid: 'test-service-instance-with-metadata')
      expect(instance[:broker_provided_metadata]).to eq(metadata_json)
    end

    it 'preserves existing service instances after migration' do
      # Insert a service instance before migration
      db[:service_instances].insert(
        guid: 'existing-service-instance-guid',
        name: 'existing-instance',
        space_id: space.id
      )
      run_migration
      # Verify the existing instance still exists and has null metadata
      instance = db[:service_instances].first(guid: 'existing-service-instance-guid')
      expect(instance).not_to be_nil
      expect(instance[:broker_provided_metadata]).to be_nil
    end
  end
end
