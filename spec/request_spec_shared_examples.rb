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
        headers = set_user_with_header_as_role(role: role, org: org, space: space, user: user, scopes: expected_codes_and_responses[role][:scopes])
        api_call.call(headers)

        expected_response_code = expected_codes_and_responses[role][:code]
        expect(last_response.status).to eq(expected_response_code), "role #{role}: expected #{expected_response_code}, got: #{last_response.status}"
        if (200...300).cover? expected_response_code
          expected_response_objects = expected_codes_and_responses[role][:response_objects]
          expect({ resources: parsed_response['resources'] }).to match_json_response({ resources: expected_response_objects })

          expect(parsed_response['pagination']).to match_json_response({
            total_results: an_instance_of(Integer),
            total_pages: an_instance_of(Integer),
            first: { href: /#{link_prefix}#{last_request.path}.+page=\d+&per_page=\d+/ },
            last: { href: /#{link_prefix}#{last_request.path}.+page=\d+&per_page=\d+/ },
            next: anything,
            previous: anything
          })
        end
      end
    end
  end
end

RSpec.shared_examples 'permissions for single object endpoint' do |roles|
  let(:expected_event_hash) { nil }

  roles.each do |role|
    describe "as an #{role}" do
      it 'returns the correct response status and resources' do
        email = Sham.email
        user_name = Sham.name
        headers = set_user_with_header_as_role({
          role: role,
          org: org,
          space: space,
          user: user,
          scopes: expected_codes_and_responses[role][:scopes],
          user_name: user_name,
          email: email,
        })

        api_call.call(headers)

        if last_response.status == 500
          expect(false).to be_truthy, "500: #{last_response.body}"
        end

        expected_response_code = expected_codes_and_responses[role][:code]
        expect(last_response.status).to eq(expected_response_code),
          "role #{role}: expected #{expected_response_code}, got: #{last_response.status}\nResponse Body: #{last_response.body[0..2000]}"
        if (200...300).cover? expected_response_code
          expected_response_object = expected_codes_and_responses[role][:response_object]
          expect(parsed_response).to match_json_response(expected_response_object)
          if expected_event_hash
            event = VCAP::CloudController::Event.last
            expect(event).not_to be_nil
            expect(event.values).to include(expected_event_hash.merge({
              actor: user.guid,
              actor_type: 'user',
              actor_name: email,
              actor_username: user_name,
            }))
          end
        end
      end
    end
  end
end

RSpec.shared_examples 'permissions for delete endpoint' do |roles|
  let(:expected_event_hash) { nil }

  roles.each do |role|
    describe "as an #{role}" do
      it 'returns the correct response status and resources' do
        email = Sham.email
        user_name = Sham.name
        headers = set_user_with_header_as_role(
          role: role,
          org: org,
          space: space,
          user: user,
          scopes: expected_codes_and_responses[role][:scopes],
          user_name: user_name,
          email: email,
        )
        api_call.call(headers)

        expected_response_code = expected_codes_and_responses[role][:code]
        expect(last_response.status).to eq(expected_response_code),
          "role #{role}: expected #{expected_response_code}, got: #{last_response.status}\nResponse Body: #{last_response.body[0..2000]}"
        if (200...300).cover? expected_response_code
          db_check.call

          if expected_event_hash
            event = VCAP::CloudController::Event.last
            expect(event).not_to be_nil
            expect(event.values).to include(expected_event_hash.merge({
              actor: user.guid,
              actor_type: 'user',
              actor_name: email,
              actor_username: user_name,
            }))
          end
        end
      end
    end
  end
end
