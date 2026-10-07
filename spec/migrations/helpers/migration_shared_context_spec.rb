require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration shared context', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260630120000_add_status_to_spaces.rb' }
  end

  it 'rejects idempotency checks in the wrong migration state without changing the database' do
    expect { test_up_migration_idempotency }.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      'Run run_migration before testing up migration idempotency'
    )

    expect(db[:schema_migrations].where(filename: migration_filename)).to be_empty
    expect(db[:spaces].columns).not_to include(:status)

    run_migration

    expect { test_down_migration_idempotency }.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      'Revert the migration before testing down migration idempotency'
    )

    expect(db[:schema_migrations].where(filename: migration_filename)).not_to be_empty
    expect(db[:spaces].columns).to include(:status)
  end
end
