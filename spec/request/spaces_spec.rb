require 'spec_helper'

RSpec.describe 'Spaces' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:organization)       { VCAP::CloudController::Organization.make name: 'Boardgames' }
  let!(:space1)            { VCAP::CloudController::Space.make name: 'Catan', organization: organization }
  let!(:space2)            { VCAP::CloudController::Space.make name: 'Ticket to Ride', organization: organization }
  let!(:space3)            { VCAP::CloudController::Space.make name: 'Agricola', organization: organization }
  let!(:unaccesable_space) { VCAP::CloudController::Space.make name: 'Ghost Stories', organization: organization }

  before do
    organization.add_user(user)
    space1.add_developer(user)
    space2.add_developer(user)
    space3.add_developer(user)
  end

  describe 'GET /v3/space' do
    it 'returns a paginated list of orgs the user has access to' do
      get '/v3/spaces?per_page=2', nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 3,
            'total_pages' => 2,
            'first' => {
              'href' => "#{link_prefix}/v3/spaces?page=1&per_page=2"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/spaces?page=2&per_page=2"
            },
            'next' => {
              'href' => "#{link_prefix}/v3/spaces?page=2&per_page=2"
            },
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => space1.guid,
              'name' => 'Catan',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {}
            },
            {
              'guid' => space2.guid,
              'name' => 'Ticket to Ride',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {}
            }
          ]
        }
      )
    end
  end
end
