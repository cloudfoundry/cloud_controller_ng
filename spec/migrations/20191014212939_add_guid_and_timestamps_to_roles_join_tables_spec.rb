require 'spec_helper'

RSpec.describe 'add role_guid and timestamps to roles join tables', isolation: :truncation, type: :migration do
  let(:db) { Sequel::Model.db }
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  org_roles = %w[
    organizations_auditors
    organizations_billing_managers
    organizations_managers
    organizations_users
  ]
  space_roles = %w[
    spaces_auditors
    spaces_developers
    spaces_managers
  ]

  before do
    space_roles.each do |s_role|
      db[s_role.to_sym].insert({
                                 user_id: user.id,
                                 space_id: space.id
                               })
    end

    org_roles.each do |o_role|
      db[o_role.to_sym].insert({
                                 user_id: user.id,
                                 organization_id: space.organization.id
                               })
    end
  end

  roles = org_roles + space_roles

  # Seven former examples (one per role table) consolidated into a single it
  # block. Each previous example ran an identical `before` (inserts into all 7
  # tables) plus the framework's per-example rollback-and-forward migration
  # cycle in `migration_shared_context`. Collapsing to one example runs that
  # cycle once instead of seven times. The assertions still cover every role
  # table; failure messages identify the specific table via the loop variable.
  # See spec/migrations/Readme.md "Group related tests into a single it block".
  it 'adds role_guid and timestamp columns to every role join table' do
    roles.each do |role_table|
      role = db[role_table.to_sym].first(user_id: user.id)

      expect(role[:role_guid]).to be_nil, "expected role_guid column on #{role_table} (was nil-or-missing)"
      expect(role[:created_at]).to be_a(Time), "expected created_at column on #{role_table}"
      expect(role[:updated_at]).to be_a(Time), "expected updated_at column on #{role_table}"
    end
  end
end
