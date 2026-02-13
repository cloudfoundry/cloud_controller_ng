require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add file-based service binding feature columns to apps table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250225132929_add_apps_file_based_service_binding_feature_columns.rb' }
  end

  describe 'apps table' do
    it 'adds and removes columns with defaults, constraints, and handles idempotency' do
      # Setup: Insert existing app to test default values
      db[:apps].insert(guid: 'existing_app_guid')

      # Verify initial state
      expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
      expect(db[:apps].columns).not_to include(:file_based_vcap_services_enabled)
      expect(check_constraint_exists?(db)).to be(false) if check_constraint_supported?(db)

      # === UP MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # Verify both columns were added
      expect(db[:apps].columns).to include(:service_binding_k8s_enabled)
      expect(db[:apps].columns).to include(:file_based_vcap_services_enabled)

      # Verify default values for existing entries
      expect(db[:apps].first(guid: 'existing_app_guid')[:service_binding_k8s_enabled]).to be(false)
      expect(db[:apps].first(guid: 'existing_app_guid')[:file_based_vcap_services_enabled]).to be(false)

      # Verify default values for new entries
      db[:apps].insert(guid: 'new_app_guid')
      expect(db[:apps].first(guid: 'new_app_guid')[:service_binding_k8s_enabled]).to be(false)
      expect(db[:apps].first(guid: 'new_app_guid')[:file_based_vcap_services_enabled]).to be(false)

      # Verify null constraints
      expect { db[:apps].insert(guid: 'app_guid_nil_k8s', service_binding_k8s_enabled: nil) }.to raise_error(Sequel::NotNullConstraintViolation)
      expect { db[:apps].insert(guid: 'app_guid_nil_vcap', file_based_vcap_services_enabled: nil) }.to raise_error(Sequel::NotNullConstraintViolation)

      # Verify check constraint (if supported)
      if check_constraint_supported?(db)
        expect(check_constraint_exists?(db)).to be(true)
        expect { db[:apps].insert(guid: 'app_both_true', file_based_vcap_services_enabled: true, service_binding_k8s_enabled: true) }.to(raise_error do |error|
          expect(error.inspect).to include('only_one_sb_feature_enabled')
        end)
      end

      # Test up migration idempotency: running migration again should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:apps].columns).to include(:service_binding_k8s_enabled)
      expect(db[:apps].columns).to include(:file_based_vcap_services_enabled)
      expect(check_constraint_exists?(db)).to be(true) if check_constraint_supported?(db)

      # === DOWN MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error

      # Verify columns were removed
      expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
      expect(db[:apps].columns).not_to include(:file_based_vcap_services_enabled)
      expect(check_constraint_exists?(db)).to be(false)

      # Test down migration idempotency: running rollback again should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
      expect(db[:apps].columns).not_to include(:file_based_vcap_services_enabled)
      expect(check_constraint_exists?(db)).to be(false)
    end
  end
end
