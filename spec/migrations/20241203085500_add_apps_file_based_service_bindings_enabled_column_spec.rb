require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add file_based_service_bindings_enabled column to apps table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20241203085500_add_apps_file_based_service_bindings_enabled_column.rb' }
  end

  describe 'apps table' do
    it 'adds column with correct properties and default values' do
      # Insert an app before migration to test default value on existing entries
      db[:apps].insert(guid: 'existing_app_guid')

      # Verify column doesn't exist yet
      expect(db[:apps].columns).not_to include(:file_based_service_bindings_enabled)

      # Run migration
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

      # Verify column was added
      expect(db[:apps].columns).to include(:file_based_service_bindings_enabled)

      # Verify default value on existing entries is false
      expect(db[:apps].first(guid: 'existing_app_guid')[:file_based_service_bindings_enabled]).to be(false)

      # Verify default value on new entries is false
      db[:apps].insert(guid: 'new_app_guid')
      expect(db[:apps].first(guid: 'new_app_guid')[:file_based_service_bindings_enabled]).to be(false)

      # Verify null values are forbidden
      expect { db[:apps].insert(guid: 'app_guid__nil', file_based_service_bindings_enabled: nil) }.to raise_error(Sequel::NotNullConstraintViolation)
    end
  end
end
