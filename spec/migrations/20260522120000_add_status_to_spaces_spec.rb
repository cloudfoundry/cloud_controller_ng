require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add status column to spaces table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260522120000_add_status_to_spaces.rb' }
  end

  describe 'spaces table' do
    it 'adds the status column with the expected properties and is idempotent' do
      quota_id = db[:quota_definitions].insert(
        guid: 'quota-guid',
        name: 'test-quota',
        non_basic_services_allowed: true,
        total_services: 10,
        total_routes: 10,
        memory_limit: 1024
      )
      org_id = db[:organizations].insert(guid: 'org-guid', name: 'an-org', quota_definition_id: quota_id)
      db[:spaces].insert(guid: 'existing-space-guid', name: 'existing-space', organization_id: org_id)

      expect(db[:spaces].columns).not_to include(:status)

      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

      expect(db[:spaces].columns).to include(:status)

      expect(db[:spaces].first(guid: 'existing-space-guid')[:status]).to eq('active')

      db[:spaces].insert(guid: 'new-space-guid', name: 'new-space', organization_id: org_id)
      expect(db[:spaces].first(guid: 'new-space-guid')[:status]).to eq('active')

      expect do
        db[:spaces].insert(guid: 'null-status-guid', name: 'null-space', organization_id: org_id, status: nil)
      end.to raise_error(Sequel::NotNullConstraintViolation)

      expect do
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
      end.not_to raise_error

      Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)
      expect(db[:spaces].columns).not_to include(:status)

      expect do
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)
      end.not_to raise_error
    end
  end
end
