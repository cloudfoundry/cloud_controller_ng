require 'spec_helper'

RSpec.describe 'Stacks Request' do
  describe 'GET /v3/stacks' do
    before { VCAP::CloudController::Stack.dataset.destroy }
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

      it 'returns a list of name filtered stacks' do
        get "/v3/stacks?names=#{stack1.name},#{stack3.name}", nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/stacks?names=#{stack1.name}%2C#{stack3.name}&page=1&per_page=50"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/stacks?names=#{stack1.name}%2C#{stack3.name}&page=1&per_page=50"
              },
              'next' => nil,
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
                'name' => stack3.name,
                'description' => stack3.description,
                'guid' => stack3.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/stacks/#{stack3.guid}"
                  }
                }
              }
            ]
          }
        )
      end
    end
  end

  describe 'GET /v3/stacks/:guid' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }

    let!(:stack) { VCAP::CloudController::Stack.make }

    it 'returns details of the requested stack' do
      get "/v3/stacks/#{stack.guid}", nil, headers
      expect(last_response.status).to eq 200
      expect(parsed_response).to be_a_response_like(
        {
          'name' => stack.name,
          'description' => stack.description,
          'guid' => stack.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/stacks/#{stack.guid}"
            }
          }
        }
      )
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

    context 'when there is a model validation failure' do
      let(:name) { 'the-name' }

      before do
        VCAP::CloudController::Stack.make name: name
      end

      it 'responds with 422' do
        post '/v3/stacks', request_body, headers
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('Name must be unique')
      end
    end
  end

  describe 'DELETE /v3/stacks/:guid' do
    let(:user) { make_user(admin: true) }
    let(:headers) { admin_headers_for(user) }
    let(:stack) { VCAP::CloudController::Stack.make }

    it 'destroys the stack' do
      delete "/v3/stacks/#{stack.guid}", {}, headers

      expect(last_response.status).to eq(204)
      expect(stack).to_not exist
    end
  end
end
