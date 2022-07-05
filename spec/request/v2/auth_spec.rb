require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Auth' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }

  before do
    @test_mode = ENV['CC_TEST']
    ENV['CC_TEST'] = nil
  end

  after do
    ENV['CC_TEST'] = @test_mode
  end

  context 'when the user has a valid token' do
    it 'returns as normal' do
      get '/v2/organizations', nil, user_header
      expect(last_response.status).to eq 200
    end
  end

  context 'when the user has an invalid or expired token' do
    it 'returns a 401' do
      get '/v2/organizations', nil, headers_for(user, expired: true)

      expect(last_response.status).to eq 401
      expect(last_response.body).to match /InvalidAuthToken/
    end
  end
  context 'when user has a global token inaddtion to the space supporter role' do
    let(:org) { VCAP::CloudController::Organization.make(created_at: 3.days.ago) }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:api_call) { lambda { |user_headers| get '/v2/apps', nil, user_headers } }
    let(:expected_codes_and_responses) { Hash.new(code: 200) }

    before do
      space.organization.add_user(user)
      space.add_supporter(user)
    end

    it_behaves_like 'permissions for list endpoint', GLOBAL_SCOPES
  end

  context 'space supporter' do
    let(:space1) { VCAP::CloudController::Space.make }
    let(:space2) { VCAP::CloudController::Space.make }
    let(:space3) { VCAP::CloudController::Space.make }

    context 'user with only space supporter role' do
      before do
        space1.organization.add_user(user)
        space1.add_supporter(user)
      end

      describe 'GET /v2 endpoints' do
        it 'errors on request' do
          get '/v2/apps', nil, user_header
          expect(last_response.status).to eq(403)
          expect(last_response.body).to match %r(You are not authorized to perform the requested action. See section 'Space Supporter Role in V2' https://docs.cloudfoundry.org/concepts/roles.html)

          get '/v2/orgs', nil, user_header
          expect(last_response.status).to eq(403)
          expect(last_response.body).to match %r(You are not authorized to perform the requested action. See section 'Space Supporter Role in V2' https://docs.cloudfoundry.org/concepts/roles.html)

          get '/v2/spaces', nil, user_header
          expect(last_response.status).to eq(403)
          expect(last_response.body).to match %r(You are not authorized to perform the requested action. See section 'Space Supporter Role in V2' https://docs.cloudfoundry.org/concepts/roles.html)
        end

        it 'does not error when hitting info' do
          get '/v2/info', nil, user_header
          expect(last_response.status).to eq(200)
        end

        it 'does not error when hitting root' do
          get '/', nil, user_header
          expect(last_response.status).to eq(200)
        end

        context 'with multiple role assignments' do
          before do
            space2.organization.add_user(user)
            space2.add_supporter(user)
          end

          it 'still throws a 403' do
            get '/v2/spaces', nil, user_header
            expect(last_response.status).to eq(403)
            expect(last_response.body).to match %r(You are not authorized to perform the requested action. See section 'Space Supporter Role in V2' https://docs.cloudfoundry.org/concepts/roles.html)
          end
        end
      end
    end

    context 'user with multiple role types' do
      before do
        space1.organization.add_user(user)
        space2.organization.add_user(user)
        space3.organization.add_user(user)
        space1.add_supporter(user)
        space2.add_developer(user)
        space3.add_developer(user)
      end

      describe 'GET /v2 endpoints' do
        it 'succeeds' do
          get '/v2/apps', nil, user_header
          expect(last_response.status).to eq(200)
        end
      end
    end

    context 'user does not have space supporter role' do
      before do
        space1.organization.add_user(user)
        space1.add_developer(user)
      end

      describe 'GET /v2 endpoints' do
        it 'succeeds' do
          get '/v2/apps', nil, user_header
          expect(last_response.status).to eq(200)
        end
      end
    end
  end
end
