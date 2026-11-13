require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add encrypted_credentials_json columns to buildpack_lifecycle_data', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20261001120000_add_buildpack_lifecycle_credentials.rb' }
  end

  describe 'buildpack_lifecycle_data table' do
    it 'adds and removes credential columns, handling idempotency gracefully' do
      # Before migration: columns must not exist
      expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json)
      expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json_salt)

      # Run up migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:buildpack_lifecycle_data].columns).to include(:encrypted_credentials_json)
      expect(db[:buildpack_lifecycle_data].columns).to include(:encrypted_credentials_json_salt)

      # Run up again - idempotent due to if_not_exists
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:buildpack_lifecycle_data].columns).to include(:encrypted_credentials_json)
      expect(db[:buildpack_lifecycle_data].columns).to include(:encrypted_credentials_json_salt)

      # Run down migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json)
      expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json_salt)

      # Run down again - idempotent due to if_exists
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json)
      expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json_salt)
    end
  end
end
