require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add encrypted_credentials_json columns to buildpack_lifecycle_data', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20261001120000_add_buildpack_lifecycle_credentials.rb' }
  end

  describe 'buildpack_lifecycle_data table' do
    it 'adds and removes credential columns' do
      # Before migration: columns must not exist
      expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json)
      expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json_salt)

      # Run up migration
      expect { run_migration }.not_to raise_error
      expect(db[:buildpack_lifecycle_data].columns).to include(:encrypted_credentials_json)
      expect(db[:buildpack_lifecycle_data].columns).to include(:encrypted_credentials_json_salt)

      # Run down migration
      expect { revert_migration }.not_to raise_error
      expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json)
      expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json_salt)
    end

    # if_not_exists:/if_exists: are only honoured on PostgreSQL, so only exercise
    # re-run idempotency there.
    context 'on postgres' do
      it 'is idempotent' do
        skip if db.database_type != :postgres

        run_migration

        test_up_migration_idempotency
        expect(db[:buildpack_lifecycle_data].columns).to include(:encrypted_credentials_json)
        expect(db[:buildpack_lifecycle_data].columns).to include(:encrypted_credentials_json_salt)

        revert_migration

        test_down_migration_idempotency
        expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json)
        expect(db[:buildpack_lifecycle_data].columns).not_to include(:encrypted_credentials_json_salt)
      end
    end
  end
end
