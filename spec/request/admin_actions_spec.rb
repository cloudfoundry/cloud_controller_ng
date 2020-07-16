require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'admin actions' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }

  describe 'POST /v3/admin/actions/clear_buildpack_cache' do
    let(:api_call) { lambda { |user_headers| post '/v3/admin/actions/clear_buildpack_cache', {}, user_headers } }

    let(:expected_codes_and_responses) do
      h = Hash.new(
        code: 403,
      )
      h['admin'] = {
        code: 202,
      }
      h.freeze
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:after_request_check) do
        lambda do
          job_guid = last_response.headers['Location'].gsub("#{link_prefix}/v3/jobs/", '')
          get "/v3/jobs/#{job_guid}", {}, admin_headers
          expect(last_response).to have_status_code(200)

          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end
      end
    end
  end
end
