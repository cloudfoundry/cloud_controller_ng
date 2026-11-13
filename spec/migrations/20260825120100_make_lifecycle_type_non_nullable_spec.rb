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
    run_migration

    expect(db.schema(:apps).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be false
    expect(db.schema(:droplets).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be false
    expect(db.schema(:builds).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be false

    test_up_migration_idempotency

    revert_migration

    expect(db.schema(:apps).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be true
    expect(db.schema(:droplets).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be true
    expect(db.schema(:builds).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be true

    test_down_migration_idempotency
    expect(db.schema(:apps).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be true
    expect(db.schema(:droplets).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be true
    expect(db.schema(:builds).find { |col| col[0] == :lifecycle_type }[1][:allow_null]).to be true
  end
end
