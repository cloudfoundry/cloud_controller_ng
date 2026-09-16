require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add gpu_enabled to apps', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260910120000_add_gpu_enabled_to_apps.rb' }
  end

  it 'adds and removes gpu_enabled with a false default (idempotent)' do
    db[:apps].insert(guid: 'existing_app_guid')
    expect(db.schema(:apps).map(&:first)).not_to include(:gpu_enabled)

    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    expect(db.schema(:apps).map(&:first)).to include(:gpu_enabled)
    expect(db[:apps].first(guid: 'existing_app_guid')[:gpu_enabled]).to be(false)
    db[:apps].insert(guid: 'new_app_guid')
    expect(db[:apps].first(guid: 'new_app_guid')[:gpu_enabled]).to be(false)
    expect { db[:apps].insert(guid: 'app_guid_nil_gpu', gpu_enabled: nil) }.to raise_error(Sequel::NotNullConstraintViolation)

    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)

    expect(db.schema(:apps).map(&:first)).not_to include(:gpu_enabled)
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
  end
end
