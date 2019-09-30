require 'spec_helper'

RSpec.describe 'add guid and timestamps to roles join tables', isolation: :truncation do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.organization.add_billing_manager(user)
    space.organization.add_auditor(user)
    space.organization.add_manager(user)
    space.add_auditor(user)
    space.add_developer(user)
    space.add_manager(user)
  end

  %w{
    organizations_auditors
    organizations_billing_managers
    organizations_managers
    organizations_users
    spaces_auditors
    spaces_developers
    spaces_managers
  }.each do |role_table|
    context role_table do
      it "adds the columns to the #{role_table} table" do
        role = VCAP::CloudController::DeploymentModel.db[role_table.to_sym].first(user_id: user.id)

        expect(role[:guid]).to be_nil
        expect(role[:created_at]).to be_a(Time)
        expect(role[:updated_at]).to be_a(Time)
      end
    end
  end
end
