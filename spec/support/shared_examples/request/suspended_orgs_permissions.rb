RSpec.shared_examples 'permissions for create endpoint when organization is suspended' do |success_code, suspended_roles|
  before do
    org.update(status: VCAP::CloudController::Organization::SUSPENDED)
  end

  it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
    let(:expected_codes_and_responses) do
      responses_for_org_suspended_space_restricted_create_endpoint(success_code:, suspended_roles:)
    end
  end
end

RSpec.shared_examples 'permissions for update endpoint when organization is suspended' do |success_code|
  before do
    org.update(status: VCAP::CloudController::Organization::SUSPENDED)
  end

  it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
    let(:expected_codes_and_responses) do
      responses_for_org_suspended_space_restricted_update_endpoint(success_code:)
    end
  end
end

RSpec.shared_examples 'permissions for delete endpoint when organization is suspended' do |success_code, suspended_roles|
  before do
    org.update(status: VCAP::CloudController::Organization::SUSPENDED)
  end

  it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
    let(:expected_codes_and_responses) do
      responses_for_org_suspended_space_restricted_delete_endpoint(success_code:, suspended_roles:)
    end
  end
end
