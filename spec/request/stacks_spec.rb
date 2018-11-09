require 'spec_helper'

RSpec.describe 'Stacks Request' do
  describe 'POST /v3/stacks' do
    let(:user) { make_user(admin: true) }
    let(:request_body) do
      {
        name: 'the-name',
        description: 'the-description',
      }.to_json
    end
    let(:headers) { admin_headers_for(user) }

    it 'creates a new stack' do
      expect {
        post '/v3/stacks', request_body, headers
      }.to change {
        VCAP::CloudController::Stack.count
      }.by 1

      created_stack = VCAP::CloudController::Stack.last

      expect(last_response.status).to eq(201)

      expect(parsed_response).to be_a_response_like(
        {
          'name' => 'the-name',
          'description' => 'the-description',
          'guid' => created_stack.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/stacks/#{created_stack.guid}"
            }
          }
        }
      )
    end
  end
end
