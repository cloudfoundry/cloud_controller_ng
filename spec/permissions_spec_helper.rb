READ_ONLY_PERMS = {
  'admin' => 200,
  'admin_read_only' => 200,
  'global_auditor' => 200,
  'space_developer' => 200,
  'space_manager' => 200,
  'space_auditor' => 200,
  'org_manager' => 200,
  'org_auditor' => 404,
  'org_billing_manager' => 404,
}.freeze

READ_AND_WRITE_PERMS = {
  'admin' => 200,
  'admin_read_only' => 403,
  'global_auditor' => 403,
  'space_developer' => 200,
  'space_manager' => 403,
  'space_auditor' => 403,
  'org_manager' => 403,
  'org_auditor' => 404,
  'org_billing_manager' => 404,
}.freeze

ROLES = [
  'admin',
  'admin_read_only',
  'global_auditor',
  'space_developer',
  'space_manager',
  'space_auditor',
  'org_manager',
  'org_auditor',
  'org_billing_manager',
].freeze

RSpec.shared_examples 'permissions endpoint' do
  ROLES.each do |role|
    describe "as an #{role}" do
      it 'returns the correct response status' do
        expected_return_value = roles_to_http_responses[role]
        set_current_user_as_role(role: role, org: org, space: space, user: user, scopes: %w(cloud_controller.read cloud_controller.write))
        api_call.call

        expect(response.status).to eq(expected_return_value), "role #{role}: expected #{expected_return_value}, got: #{response.status}"
      end
    end
  end
end
