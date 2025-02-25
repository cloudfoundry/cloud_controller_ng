require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add service_binding_k8s_enabled column to apps table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250225132929_add_apps_service_binding_k8s_enabled_column.rb' }
  end

  describe 'apps table' do
    subject(:run_migration) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }

    it 'adds a column `service_binding_k8s_enabled`' do
      expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
      run_migration
      expect(db[:apps].columns).to include(:service_binding_k8s_enabled)
    end

    it 'sets the default value of existing entries to false' do
      db[:apps].insert(guid: 'existing_app_guid')
      run_migration
      expect(db[:apps].first(guid: 'existing_app_guid')[:service_binding_k8s_enabled]).to be(false)
    end

    it 'sets the default value of new entries to false' do
      run_migration
      db[:apps].insert(guid: 'new_app_guid')
      expect(db[:apps].first(guid: 'new_app_guid')[:service_binding_k8s_enabled]).to be(false)
    end

    it 'forbids null values' do
      run_migration
      expect { db[:apps].insert(guid: 'app_guid__nil', service_binding_k8s_enabled: nil) }.to raise_error(Sequel::NotNullConstraintViolation)
    end
  end
end
