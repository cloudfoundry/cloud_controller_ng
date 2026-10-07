require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to make lifecycle_type non-nullable on apps, droplets, and builds', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260825120100_make_lifecycle_type_non_nullable.rb' }
  end

  before do
    db[:apps].insert(guid: 'app-guid', lifecycle_type: 'buildpack')
    db[:droplets].insert(guid: 'droplet-guid', state: 'STAGED', lifecycle_type: 'buildpack')
    db[:builds].insert(guid: 'build-guid', lifecycle_type: 'buildpack')
  end

  it 'makes lifecycle_type non-nullable, is reversible, and is idempotent' do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    expect(db.schema(:apps).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be false
    expect(db.schema(:droplets).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be false
    expect(db.schema(:builds).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be false

    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)

    expect(db.schema(:apps).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be true
    expect(db.schema(:droplets).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be true
    expect(db.schema(:builds).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be true
  end
end
