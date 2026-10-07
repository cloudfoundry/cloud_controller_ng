require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to allow multiple service bindings', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20251015071027_allow_multiple_service_bindings.rb' }
  end

  describe 'service_bindings table' do
    it 'replaces unique constraints with indexes and handles idempotency' do
      # Verify initial state
      expect(db.indexes(:service_bindings)).to include(:unique_service_binding_service_instance_guid_app_guid)
      expect(db.indexes(:service_bindings)).to include(:unique_service_binding_app_guid_name)
      expect(db.indexes(:service_bindings)).not_to include(:service_bindings_app_guid_service_instance_guid_index)
      expect(db.indexes(:service_bindings)).not_to include(:service_bindings_app_guid_name_index)

      # === UP MIGRATION ===
      expect { run_migration }.not_to raise_error
      expect(db.indexes(:service_bindings)).not_to include(:unique_service_binding_app_guid_name)
      expect(db.indexes(:service_bindings)).not_to include(:unique_service_binding_service_instance_guid_app_guid)
      expect(db.indexes(:service_bindings)).to include(:service_bindings_app_guid_service_instance_guid_index)
      expect(db.indexes(:service_bindings)).to include(:service_bindings_app_guid_name_index)

      # Test up migration idempotency
      test_up_migration_idempotency
      expect(db.indexes(:service_bindings)).to include(:service_bindings_app_guid_service_instance_guid_index)
      expect(db.indexes(:service_bindings)).to include(:service_bindings_app_guid_name_index)

      # === DOWN MIGRATION ===
      expect { revert_migration }.not_to raise_error
      expect(db.indexes(:service_bindings)).to include(:unique_service_binding_service_instance_guid_app_guid)
      expect(db.indexes(:service_bindings)).to include(:unique_service_binding_app_guid_name)
      expect(db.indexes(:service_bindings)).not_to include(:service_bindings_app_guid_service_instance_guid_index)
      expect(db.indexes(:service_bindings)).not_to include(:service_bindings_app_guid_name_index)

      # Test down migration idempotency
      test_down_migration_idempotency
      expect(db.indexes(:service_bindings)).to include(:unique_service_binding_service_instance_guid_app_guid)
      expect(db.indexes(:service_bindings)).to include(:unique_service_binding_app_guid_name)
    end
  end
end
