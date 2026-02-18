GLOBAL_SCOPES = %w[
  admin
  admin_read_only
  global_auditor
].freeze

LOCAL_ROLES = %w[
  space_developer
  space_manager
  space_auditor
  space_supporter
  org_manager
  org_auditor
  org_billing_manager
  no_role
].freeze

ALL_PERMISSIONS = (LOCAL_ROLES + GLOBAL_SCOPES).freeze

CF_NOT_AUTHORIZED = [
  { detail: 'You are not authorized to perform the requested action',
    title: 'CF-NotAuthorized',
    code: 10_003 }
].freeze

CF_ORG_SUSPENDED = [
  { detail: 'The organization is suspended',
    title: 'CF-OrgSuspended',
    code: 10_017 }
].freeze

RSpec.shared_examples 'paginated response' do |endpoint|
  it 'returns pagination information' do
    expect_filtered_resources(endpoint, 'per_page=1', resources[0, 1])

    expect(parsed_response['pagination']['total_results']).to eq(resources.length)
    expect(parsed_response['pagination']['total_pages']).to eq(resources.length)
    expect(parsed_response['pagination']['first']['href']).to include("#{endpoint}?page=1&per_page=1")
    expect(parsed_response['pagination']['next']['href']).to include("#{endpoint}?page=2&per_page=1")
    expect(parsed_response['pagination']['last']['href']).to include("#{endpoint}?page=#{resources.length}&per_page=1")
  end

  it 'keeps filtering information in links' do
    resources_names = resources.map(&:name)
    expect_filtered_resources(endpoint, "per_page=1&names=#{resources_names.join(',')}", resources[0, 1])
    expect(parsed_response['pagination']['next']['href']).to include("names=#{resources_names.join('%2C')}")
  end
end

def expect_filtered_resources(endpoint, filter, list)
  get("#{endpoint}?#{filter}", nil, admin_headers)
  expect(last_response).to have_status_code(200)
  expect(parsed_response.fetch('resources').length).to eq(list.length)

  returned_guids = parsed_response['resources'].pluck('guid')
  resources_guids = list.map(&:guid)
  expect(returned_guids).to match_array(resources_guids)
end

RSpec.shared_examples 'paginated fields response' do |endpoint, resource, keys|
  it 'presents the fields correctly in first, last and next' do
    filter = "fields[#{resource}]=#{keys}&per_page=1"
    get "#{endpoint}?#{filter}", nil, admin_headers
    expect(last_response).to have_status_code(200)

    keys = keys.split(',').join('%2C')
    last_page = resources.length
    expect(parsed_response['pagination']['first']['href']).to include("#{endpoint}?fields%5B#{resource}%5D=#{keys}&page=1&per_page=1")
    expect(parsed_response['pagination']['next']['href']).to include("#{endpoint}?fields%5B#{resource}%5D=#{keys}&page=2&per_page=1")
    expect(parsed_response['pagination']['last']['href']).to include("#{endpoint}?fields%5B#{resource}%5D=#{keys}&page=#{last_page}&per_page=1")
  end
end

RSpec.shared_examples 'permissions for list endpoint' do |roles|
  roles.each do |role|
    describe "as an #{role}" do
      it 'returns the correct response status and resources' do
        headers = set_user_with_header_as_role(role: role, org: org, space: space, user: user, scopes: expected_codes_and_responses[role][:scopes])
        api_call.call(headers)

        unrecognized_keys = expected_codes_and_responses[role].keys - %i[code response_guids response_objects scopes]
        raise("Unrecognized expected_codes_and_responses key(s) for #{role}: #{unrecognized_keys}") unless unrecognized_keys.empty?

        expected_response_code = expected_codes_and_responses[role][:code]
        expect(last_response).to have_status_code(expected_response_code)

        expected_response_objects = expected_codes_and_responses[role][:response_objects]

        if (200...300).cover?(expected_response_code) && expected_response_objects
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

        expected_response_guids = expected_codes_and_responses[role][:response_guids]
        expect((parsed_response['resources'] || parsed_response['data']).pluck('guid')).to match_array(expected_response_guids) if expected_response_guids
      end
    end
  end
end

RSpec.shared_examples 'permissions for single object endpoint' do |roles|
  let(:expected_event_hash) { nil }
  let(:expected_events) { nil }
  let(:after_request_check) { -> {} }

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
          email: email
        )

        api_call.call(headers)

        unrecognized_keys = expected_codes_and_responses[role].keys - %i[code errors response_guid response_object scopes]
        raise("Unrecognized expected_codes_and_responses key(s) for #{role}: #{unrecognized_keys}") unless unrecognized_keys.empty?

        expected_response_code = expected_codes_and_responses[role][:code]
        expect(last_response).to have_status_code(expected_response_code)

        if (200...300).cover? expected_response_code
          if expected_response_code == 202
            job_location = last_response.headers['Location']
            expect(job_location).to match(%r{http.+/v3/jobs/[a-fA-F0-9-]+}) unless job_location.nil?
          end
          expected_response_object = expected_codes_and_responses[role][:response_object]

          expect(parsed_response).to match_json_response(expected_response_object) unless expected_response_object.nil?

          after_request_check.call

          if expected_event_hash
            event = VCAP::CloudController::Event.last
            expect(event).not_to be_nil
            expect(event.values).to include(expected_event_hash.merge({
                                                                        actor: user.guid,
                                                                        actor_type: 'user',
                                                                        actor_name: email,
                                                                        actor_username: user_name
                                                                      }))
          end

          expect(expected_events.call(email)).to be_reported_as_events if expected_events
        elsif (400...499).cover? expected_response_code
          expected_errors = expected_codes_and_responses[role][:errors]
          expect({ errors: errors_without_test_mode_info(parsed_response) }).to match_json_response({ errors: expected_errors }) unless expected_errors.nil?
        end

        expected_response_guid = expected_codes_and_responses[role][:response_guid]
        expect(parsed_response['guid']).to eq(expected_response_guid) if expected_response_guid
      end
    end
  end
end

def errors_without_test_mode_info(parsed_response)
  expect(parsed_response).to include('errors')
  parsed_response['errors'].map { |e| e.except('test_mode_info') }
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
          email: email
        )
        api_call.call(headers)

        unrecognized_keys = expected_codes_and_responses[role].keys - %i[code scopes errors]
        raise("Unrecognized expected_codes_and_responses key(s) for #{role}: #{unrecognized_keys}") unless unrecognized_keys.empty?

        expected_response_code = expected_codes_and_responses[role][:code]
        expect(last_response).to have_status_code(expected_response_code)

        if (200...300).cover? expected_response_code
          db_check.call

          if expected_event_hash
            event = VCAP::CloudController::Event.last
            expect(event).not_to be_nil
            expect(event.values).to include(expected_event_hash.merge({
                                                                        actor: user.guid,
                                                                        actor_type: 'user',
                                                                        actor_name: email,
                                                                        actor_username: user_name
                                                                      }))
          end
        elsif (400...499).cover? expected_response_code
          expected_errors = expected_codes_and_responses[role][:errors]
          expect({ errors: errors_without_test_mode_info(parsed_response) }).to match_json_response({ errors: expected_errors }) unless expected_errors.nil?
        end
      end
    end
  end
end

RSpec.shared_examples 'list query endpoint' do
  let(:excluded_params) { [] }
  it 'returns 200 even using all possible query parameters' do
    expect(user_header).to be_present, 'user header not provided (should be provided in a `let` block)'

    missing_params = message::ALLOWED_KEYS - params.keys - excluded_params
    expect(missing_params.length).to eq(0), "Parameters #{missing_params.join(' ,')} are not provided."

    get request, params.to_query, user_header
    expect(last_response.status).to eq(200), Oj.load(last_response.body)['errors'].try(:first).try(:[], 'detail')
  end
end

RSpec.shared_examples 'resource with metadata' do
  # override these
  let(:resource) do
    # e.g:
    # Space.make
  end
  let(:api_call) do
    # e.g:
    # -> { delete "/v3/spaces/#{space.guid}", nil, admin_header }
  end

  it 'can be deleted when it has associated annotations' do
    resource.add_annotation(key_name: 'foo', key_prefix: 'bar', value: 'some value')
    api_call.call
    expect(last_response.status).to eq(202).or eq(204)
    if last_response.status == 202
      expect(last_response.headers['Location']).to match(%r{http.+/v3/jobs/[a-fA-F0-9-]+})
      successes, failures = Delayed::Worker.new.work_off
      expect(successes).to be >= 1
      expect(failures).to be 0
    end
    expect(resource).not_to exist
  end

  it 'can be deleted when it has associated labels' do
    resource.add_label(key_name: 'foo', key_prefix: 'bar', value: 'some value')
    api_call.call
    expect(last_response.status).to eq(202).or eq(204)
    if last_response.status == 202
      expect(last_response.headers['Location']).to match(%r{http.+/v3/jobs/[a-fA-F0-9-]+})
      successes, failures = Delayed::Worker.new.work_off
      expect(successes).to be >= 1
      expect(failures).to be 0
    end
    expect(resource).not_to exist
  end
end

RSpec.shared_examples 'list_endpoint_with_common_filters' do
  let(:resource_klass) { raise 'Please define a resource_klass!' }
  let(:api_call) { ->(_headers, _filter) { raise 'Please define an api_call!' } }
  let(:headers) { raise 'Please define headers to use for the api call' }
  let(:additional_resource_params) { {} }

  context 'filtering guids' do
    let!(:resource_1) { resource_klass.make(guid: '1', **additional_resource_params) }
    let!(:resource_2) { resource_klass.make(guid: '2', **additional_resource_params) }
    let!(:resource_3) { resource_klass.make(guid: '3', **additional_resource_params) }

    it 'filters on guid' do
      api_call.call(headers, 'guids=1,2,4')
      expect(last_response).to have_status_code(200)
      expect(parsed_response['resources'].pluck('guid')).to contain_exactly('1', '2')
    end
  end

  context 'filtering timestamps on creation' do
    let!(:resource_1) { resource_klass.make(guid: '1', created_at: '2020-05-26T18:47:01Z', **additional_resource_params) }
    let!(:resource_2) { resource_klass.make(guid: '2', created_at: '2020-05-26T18:47:02Z', **additional_resource_params) }
    let!(:resource_3) { resource_klass.make(guid: '3', created_at: '2020-05-26T18:47:03Z', **additional_resource_params) }
    let!(:resource_4) { resource_klass.make(guid: '4', created_at: '2020-05-26T18:47:04Z', **additional_resource_params) }

    it 'filters' do
      api_call.call(headers, "created_ats[lt]=#{resource_3.created_at.iso8601}")

      expect(last_response).to have_status_code(200)
      expect(parsed_response['resources'].pluck('guid')).to contain_exactly(resource_1.guid, resource_2.guid)
    end
  end

  context 'filtering timestamps on update' do
    # before must occur before the let! otherwise the resources will be created with
    # update_on_create: true
    before do
      resource_klass.plugin :timestamps, update_on_create: false
    end

    let!(:resource_1) { resource_klass.make(guid: '1', updated_at: '2020-05-26T18:47:01Z', **additional_resource_params) }
    let!(:resource_2) { resource_klass.make(guid: '2', updated_at: '2020-05-26T18:47:02Z', **additional_resource_params) }
    let!(:resource_3) { resource_klass.make(guid: '3', updated_at: '2020-05-26T18:47:03Z', **additional_resource_params) }
    let!(:resource_4) { resource_klass.make(guid: '4', updated_at: '2020-05-26T18:47:04Z', **additional_resource_params) }

    after do
      resource_klass.plugin :timestamps, update_on_create: true
    end

    it 'filters' do
      api_call.call(headers, "updated_ats[lt]=#{resource_3.updated_at.iso8601}")

      expect(last_response).to have_status_code(200)
      expect(parsed_response['resources'].pluck('guid')).to contain_exactly(resource_1.guid, resource_2.guid)
    end
  end
end

RSpec.shared_examples 'list endpoint order_by name' do |endpoint|
  let(:resource_klass) { raise 'Please define a resource_klass!' }
  let(:additional_resource_params) { {} }

  let!(:resource_1) { resource_klass.make(guid: '1', name: 'flopsy', **additional_resource_params) }
  let!(:resource_2) { resource_klass.make(guid: '2', name: 'mopsy', **additional_resource_params) }
  let!(:resource_3) { resource_klass.make(guid: '3', name: 'cottontail', **additional_resource_params) }
  let!(:resource_4) { resource_klass.make(guid: '4', name: 'peter', **additional_resource_params) }

  it 'sorts ascending' do
    get("#{endpoint}?order_by=name", nil, admin_headers)
    expect(last_response).to have_status_code(200)
    expect(parsed_response['resources'][0]['name']).to eq('cottontail')
    expect(parsed_response['resources'][1]['name']).to eq('flopsy')
    expect(parsed_response['resources'][2]['name']).to eq('mopsy')
    expect(parsed_response['resources'][3]['name']).to eq('peter')
  end

  it 'sorts descending' do
    get("#{endpoint}?order_by=-name", nil, admin_headers)
    expect(last_response).to have_status_code(200)
    expect(parsed_response['resources'][0]['name']).to eq('peter')
    expect(parsed_response['resources'][1]['name']).to eq('mopsy')
    expect(parsed_response['resources'][2]['name']).to eq('flopsy')
    expect(parsed_response['resources'][3]['name']).to eq('cottontail')
  end
end

RSpec.shared_examples 'list endpoint order_by timestamps' do |endpoint|
  let(:resource_klass) { raise 'Please define a resource_klass!' }
  let(:additional_resource_params) { {} }

  context 'order_by created_at' do
    let!(:resource_1) { resource_klass.make(guid: '1', created_at: '2020-05-26T18:47:03Z', **additional_resource_params) }
    let!(:resource_2) { resource_klass.make(guid: '2', created_at: '2020-05-26T18:47:02Z', **additional_resource_params) }
    let!(:resource_3) { resource_klass.make(guid: '3', created_at: '2020-05-26T18:47:01Z', **additional_resource_params) }
    let!(:resource_4) { resource_klass.make(guid: '4', created_at: '2020-05-26T18:47:04Z', **additional_resource_params) }

    it 'sorts ascending' do
      get("#{endpoint}?order_by=created_at", nil, admin_headers)
      expect(last_response).to have_status_code(200)
      expect(parsed_response['resources'][0]['guid']).to eq('3')
      expect(parsed_response['resources'][1]['guid']).to eq('2')
      expect(parsed_response['resources'][2]['guid']).to eq('1')
      expect(parsed_response['resources'][3]['guid']).to eq('4')
    end

    it 'sorts descending' do
      get("#{endpoint}?order_by=-created_at", nil, admin_headers)
      expect(last_response).to have_status_code(200)
      expect(parsed_response['resources'][0]['guid']).to eq('4')
      expect(parsed_response['resources'][1]['guid']).to eq('1')
      expect(parsed_response['resources'][2]['guid']).to eq('2')
      expect(parsed_response['resources'][3]['guid']).to eq('3')
    end
  end

  context 'order_by updated_at' do
    # before must occur before the let! otherwise the resources will be created with
    # update_on_create: true
    before do
      resource_klass.plugin :timestamps, update_on_create: false
    end

    let!(:resource_1) { resource_klass.make(guid: '1', updated_at: '2020-05-26T18:47:03Z', **additional_resource_params) }
    let!(:resource_2) { resource_klass.make(guid: '2', updated_at: '2020-05-26T18:47:02Z', **additional_resource_params) }
    let!(:resource_3) { resource_klass.make(guid: '3', updated_at: '2020-05-26T18:47:01Z', **additional_resource_params) }
    let!(:resource_4) { resource_klass.make(guid: '4', updated_at: '2020-05-26T18:47:04Z', **additional_resource_params) }

    after do
      resource_klass.plugin :timestamps, update_on_create: true
    end

    it 'sorts ascending' do
      get("#{endpoint}?order_by=updated_at", nil, admin_headers)
      expect(last_response).to have_status_code(200)
      expect(parsed_response['resources'][0]['guid']).to eq('3')
      expect(parsed_response['resources'][1]['guid']).to eq('2')
      expect(parsed_response['resources'][2]['guid']).to eq('1')
      expect(parsed_response['resources'][3]['guid']).to eq('4')
    end

    it 'sorts descending' do
      get("#{endpoint}?order_by=-updated_at", nil, admin_headers)
      expect(last_response).to have_status_code(200)
      expect(parsed_response['resources'][0]['guid']).to eq('4')
      expect(parsed_response['resources'][1]['guid']).to eq('1')
      expect(parsed_response['resources'][2]['guid']).to eq('2')
      expect(parsed_response['resources'][3]['guid']).to eq('3')
    end
  end
end
