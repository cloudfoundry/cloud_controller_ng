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
    let(:space) { VCAP::CloudController::Space.make }

    it 'adds broker_provided_metadata column with correct properties' do
      # Insert a service instance before migration to test preservation
      db[:service_instances].insert(
        guid: 'existing-service-instance-guid',
        name: 'existing-instance',
        space_id: space.id
      )

      # Verify column doesn't exist yet
      expect(db[:service_instances].columns).not_to include(:broker_provided_metadata)

      # Run migration
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

      # Verify column was added
      expect(db[:service_instances].columns).to include(:broker_provided_metadata)

      # Verify existing instance was preserved with null metadata
      existing_instance = db[:service_instances].first(guid: 'existing-service-instance-guid')
      expect(existing_instance).not_to be_nil
      expect(existing_instance[:broker_provided_metadata]).to be_nil

      # Verify null values are allowed
      db[:service_instances].insert(
        guid: 'test-service-instance-guid',
        name: 'test-instance',
        space_id: space.id,
        broker_provided_metadata: nil
      )
      instance_with_null = db[:service_instances].first(guid: 'test-service-instance-guid')
      expect(instance_with_null[:broker_provided_metadata]).to be_nil

      # Verify text values are accepted
      metadata_json = '{"labels": {"version": "1.0"}, "attributes": {"engine": "postgresql"}}'
      db[:service_instances].insert(
        guid: 'test-service-instance-with-metadata',
        name: 'test-instance-with-metadata',
        space_id: space.id,
        broker_provided_metadata: metadata_json
      )
      instance_with_metadata = db[:service_instances].first(guid: 'test-service-instance-with-metadata')
      expect(instance_with_metadata[:broker_provided_metadata]).to eq(metadata_json)
    end
  end
end
