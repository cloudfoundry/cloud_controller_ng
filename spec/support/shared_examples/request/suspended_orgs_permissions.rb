RSpec.shared_examples 'permissions for update endpoint when organization is suspended' do |success_code|
  before do
    org.status = VCAP::CloudController::Organization::SUSPENDED
    org.save
  end

  it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
    let(:expected_codes_and_responses) do
      expected_codes || responses_for_org_suspended_space_restricted_update_endpoint(success_code: success_code)
    end
  end
end

RSpec.shared_examples 'permissions for create endpoint when organization is suspended' do |success_code|
  before do
    org.status = VCAP::CloudController::Organization::SUSPENDED
    org.save
  end

  it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
    let(:expected_codes_and_responses) { responses_for_org_suspended_space_restricted_create_endpoint success_code: success_code }
  end
end

RSpec.shared_examples 'permissions for delete endpoint when organization is suspended' do |success_code|
  before do
    org.status = VCAP::CloudController::Organization::SUSPENDED
    org.save
  end

  it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
    let(:expected_codes_and_responses) do
      expected_codes ||
        responses_for_org_suspended_space_restricted_delete_endpoint(success_code: success_code)
    end
  end
end
