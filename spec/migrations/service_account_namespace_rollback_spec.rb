require 'spec_helper'

RSpec.describe 'Service account namespace rollback', isolation: :truncation do
  it 'allows reverting an empty namespace transition' do
    db = Sequel::Model.db
    expect(db[:service_accounts].count).to eq(0)
    expect { Sequel::Migrator.run(db, DBMigrator::SEQUEL_MIGRATIONS, target: 20261109122999) }.not_to raise_error
    Sequel::Migrator.run(db, DBMigrator::SEQUEL_MIGRATIONS)
  end
end
