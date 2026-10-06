require 'spec_helper'

RSpec.describe 'service account app relationship migration' do
  it 'matches MySQL parent collation when retrying a partially applied migration' do
    db = Sequel.mock(host: :mysql, fetch: [{ Field: 'guid', Collation: 'utf8mb3_general_ci' }])
    allow(db).to receive(:schema).with(:apps).and_return([[:service_account_guid, { type: :string }]])
    load File.expand_path('../../db/migrations/20261005120100_add_app_service_account.rb', __dir__)
    migration = Sequel::Migration.descendants.last
    migration.apply(db, :up)
    expect(db.sqls.join).to include('COLLATE utf8mb3_general_ci')
  end
end
