require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'service account reference indexes', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20261112120000_add_service_account_reference_indexes.rb' }
  end

  it 'adds account-first indexes, supports retry after partial creation and removes them on rollback' do
    expected_indexes = {
      service_bindings: [:service_bindings_service_account_guid_index, [:service_account_guid]],
      processes: [:processes_service_account_guid_state_index, %i[service_account_guid state]],
      tasks: [:tasks_service_account_guid_state_index, %i[service_account_guid state]]
    }
    expected_indexes.each do |table, (name, _columns)|
      expect(db.indexes(table)).not_to have_key(name)
    end

    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
    expected_indexes.each do |table, (name, columns)|
      expect(db.indexes(table)[name]).to include(columns: columns, unique: false)
    end

    # Simulate an interrupted run with the first index already installed.
    load File.join(migrations_path, migration_filename)
    migration = Sequel::Migration.descendants.last
    %i[processes tasks].each do |table|
      name, columns = expected_indexes.fetch(table)
      db.drop_index(table, columns, name: name, concurrently: db.database_type == :postgres)
    end
    expect { migration.apply(db, :up) }.not_to raise_error
    expected_indexes.each do |table, (name, columns)|
      expect(db.indexes(table)[name]).to include(columns: columns)
    end

    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)
    expected_indexes.each do |table, (name, _columns)|
      expect(db.indexes(table)).not_to have_key(name)
    end
    expect { migration.apply(db, :down) }.not_to raise_error
  end

  it 'repairs invalid PostgreSQL indexes while preserving valid indexes on subsequent retries' do
    skip 'PostgreSQL concurrent index validity' unless db.database_type == :postgres

    names = %w[service_bindings_service_account_guid_index processes_service_account_guid_state_index tasks_service_account_guid_state_index]
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
    load File.join(migrations_path, migration_filename)
    migration = Sequel::Migration.descendants.last
    names.each do |name|
      db.run("UPDATE pg_index SET indisvalid = false WHERE indexrelid = '#{name}'::regclass")
    end

    migration.apply(db, :up)

    names.each do |name|
      expect(db.fetch("SELECT indisvalid FROM pg_index WHERE indexrelid = '#{name}'::regclass").get(:indisvalid)).to be(true)
    end
    expect(db).not_to receive(:add_index)
    expect(db).not_to receive(:drop_index)
    migration.apply(db, :up)
  ensure
    names&.each do |name|
      db.run("UPDATE pg_index SET indisvalid = true WHERE indexrelid = '#{name}'::regclass")
    end
  end
end
