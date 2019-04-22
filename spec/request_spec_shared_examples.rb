GLOBAL_SCOPES = %w[
  admin
  admin_read_only
  global_auditor
].freeze

LOCAL_ROLES = %w[
  space_developer
  space_manager
  space_auditor
  org_manager
  org_auditor
  org_billing_manager
  no_role
].freeze

ALL_PERMISSIONS = (LOCAL_ROLES + GLOBAL_SCOPES).freeze

RSpec.shared_examples 'permissions for list endpoint' do |roles|
  roles.each do |role|
    describe "as an #{role}" do
      it 'returns the correct response status and resources' do
        headers = set_user_with_header_as_role(role: role, org: org, space: space, user: user)
        api_call.call(headers)

        expected_response_code = expected_codes_and_responses[role][:code]
        expect(last_response.status).to eq(expected_response_code), "role #{role}: expected #{expected_response_code}, got: #{last_response.status}"
        if (200...300).cover? expected_response_code
          expected_response_objects = expected_codes_and_responses[role][:response_objects]
          expect({ resources: parsed_response['resources'] }.deep_symbolize_keys).to match({ resources: expected_response_objects })
        end
      end
    end
  end
end

RSpec.shared_examples 'permissions for single object endpoint' do |roles|
  roles.each do |role|
    describe "as an #{role}" do
      it 'returns the correct response status and resources' do
        headers = set_user_with_header_as_role(role: role, org: org, space: space, user: user)
        api_call.call(headers)

        expected_response_code = expected_codes_and_responses[role][:code]
        expect(last_response.status).to eq(expected_response_code), "role #{role}: expected #{expected_response_code}, got: #{last_response.status}"
        if (200...300).cover? expected_response_code
          expected_response_object = expected_codes_and_responses[role][:response_object]
          expect(parsed_response.deep_symbolize_keys).to match(expected_response_object)
        end
      end
    end
  end
end
