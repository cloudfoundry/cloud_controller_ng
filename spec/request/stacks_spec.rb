require 'spec_helper'

RSpec.describe 'Stacks Request' do
  describe 'GET /v3/stacks' do
    before { VCAP::CloudController::Stack.dataset.destroy
    }
    let(:user) { make_user }
    let(:headers) { headers_for(user) }

    it 'returns 200 OK' do
      get '/v3/stacks', nil, headers
      expect(last_response.status).to eq(200)
    end

    context 'When stacks exist' do
      let!(:stack1) { VCAP::CloudController::Stack.make }
      let!(:stack2) { VCAP::CloudController::Stack.make }
      let!(:stack3) { VCAP::CloudController::Stack.make }

      it 'returns a paginated list of stacks' do
        get '/v3/stacks?page=1&per_page=2', nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 3,
              'total_pages' => 2,
              'first' => {
                'href' => "#{link_prefix}/v3/stacks?page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/stacks?page=2&per_page=2"
              },
              'next' => {
                'href' => "#{link_prefix}/v3/stacks?page=2&per_page=2"
              },
              'previous' => nil
            },
            'resources' => [
              {
                'name' => stack1.name,
                'description' => stack1.description,
                'guid' => stack1.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/stacks/#{stack1.guid}"
                  }
                }
              },
              {
                'name' => stack2.name,
                'description' => stack2.description,
                'guid' => stack2.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/stacks/#{stack2.guid}"
                  }
                }
              }
            ]
          }
        )
      end
    end
  end

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
