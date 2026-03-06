require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add state column to stacks table', isolation: :truncation, type: :migration do
  subject(:run_migration) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }

  include_context 'migration' do
    let(:migration_filename) { '20251117123719_add_state_to_stacks.rb' }
  end

  it 'adds state column with defaults/constraints (up) and removes it (down), idempotently' do
    # Setup: insert existing stack before migration
    db[:stacks].insert(guid: SecureRandom.uuid, name: 'existing-stack', description: 'An existing stack')
    expect(db[:stacks].columns).not_to include(:state)

    # Run migration UP
    run_migration

    # Verify column was added with correct behavior
    expect(db[:stacks].columns).to include(:state)
    expect(db[:stacks].first(name: 'existing-stack')[:state]).to eq('ACTIVE')

    db[:stacks].insert(guid: SecureRandom.uuid, name: 'new-stack', description: 'A new stack')
    expect(db[:stacks].first(name: 'new-stack')[:state]).to eq('ACTIVE')

    expect do
      db[:stacks].insert(guid: SecureRandom.uuid, name: 'null-state-stack', description: 'A stack with null state', state: nil)
    end.to raise_error(Sequel::NotNullConstraintViolation)

    %w[DEPRECATED RESTRICTED DISABLED].each do |state|
      db[:stacks].insert(guid: SecureRandom.uuid, name: "stack-#{state.downcase}", description: "A #{state} stack", state: state)
      expect(db[:stacks].first(name: "stack-#{state.downcase}")[:state]).to eq(state)
    end

    # Verify UP is idempotent
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    # Run migration DOWN
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)
    expect(db[:stacks].columns).not_to include(:state)

    # Verify DOWN is idempotent
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
    expect(db[:stacks].columns).not_to include(:state)
  end
end
