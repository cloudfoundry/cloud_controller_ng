require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Stacks State Management' do
  let(:stack_config_file) { File.join(Paths::FIXTURES, 'config/stacks.yml') }
  let(:user) { make_user(admin: true) }
  let(:headers) { admin_headers_for(user) }

  before { VCAP::CloudController::Stack.configure(stack_config_file) }

  describe 'POST /v3/stacks with state' do
    context 'when creating stack with explicit state' do
      %w[ACTIVE DEPRECATED RESTRICTED DISABLED].each do |state|
        it "creates stack with #{state} state" do
          request_body = {
            name: "stack-#{state.downcase}",
            description: 'test stack',
            state: state
          }.to_json

          post '/v3/stacks', request_body, headers

          expect(last_response.status).to eq(201)
          expect(parsed_response['state']).to eq(state)
          expect(parsed_response['name']).to eq("stack-#{state.downcase}")
        end
      end
    end

    context 'when creating stack without state' do
      it 'defaults to ACTIVE' do
        request_body = {
          name: 'default-state-stack',
          description: 'test stack'
        }.to_json

        post '/v3/stacks', request_body, headers

        expect(last_response.status).to eq(201)
        expect(parsed_response['state']).to eq('ACTIVE')
      end
    end

    context 'when creating stack with invalid state' do
      it 'returns validation error' do
        request_body = {
          name: 'invalid-stack',
          state: 'INVALID_STATE'
        }.to_json

        post '/v3/stacks', request_body, headers

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'].first['detail']).to include('must be one of ACTIVE, RESTRICTED, DEPRECATED, DISABLED')
      end
    end

    context 'as non-admin user' do
      let(:non_admin_user) { make_user }
      let(:non_admin_headers) { headers_for(non_admin_user) }

      it 'is unauthorized' do
        request_body = {
          name: 'test-stack',
          state: 'ACTIVE'
        }.to_json

        post '/v3/stacks', request_body, non_admin_headers

        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'PATCH /v3/stacks/:guid with state' do
    let!(:stack) { VCAP::CloudController::Stack.make(name: 'test-stack', state: 'ACTIVE') }

    context 'when updating state through lifecycle' do
      it 'transitions from ACTIVE to DEPRECATED' do
        request_body = { state: 'DEPRECATED' }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state']).to eq('DEPRECATED')

        stack.reload
        expect(stack.state).to eq('DEPRECATED')
      end

      it 'transitions from DEPRECATED to RESTRICTED' do
        stack.update(state: 'DEPRECATED')

        request_body = { state: 'RESTRICTED' }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state']).to eq('RESTRICTED')
      end

      it 'transitions from RESTRICTED to DISABLED' do
        stack.update(state: 'RESTRICTED')

        request_body = { state: 'DISABLED' }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state']).to eq('DISABLED')
      end

      it 'allows transition back to ACTIVE' do
        stack.update(state: 'DEPRECATED')

        request_body = { state: 'ACTIVE' }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state']).to eq('ACTIVE')
      end
    end

    context 'when updating with invalid state' do
      it 'returns validation error' do
        request_body = { state: 'BOGUS_STATE' }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'].first['detail']).to include('must be one of ACTIVE, RESTRICTED, DEPRECATED, DISABLED')
      end
    end

    context 'when updating metadata without changing state' do
      it 'preserves existing state' do
        stack.update(state: 'DEPRECATED')

        request_body = {
          metadata: {
            labels: { test: 'label' }
          }
        }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state']).to eq('DEPRECATED')
        expect(parsed_response['metadata']['labels']['test']).to eq('label')
      end
    end

    context 'as non-admin user' do
      let(:non_admin_user) { make_user }
      let(:non_admin_headers) { headers_for(non_admin_user) }

      it 'is unauthorized' do
        request_body = { state: 'DEPRECATED' }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, non_admin_headers

        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'GET /v3/stacks/:guid' do
    let!(:deprecated_stack) { VCAP::CloudController::Stack.make(state: 'DEPRECATED') }
    let(:reader_user) { make_user }
    let(:reader_headers) { headers_for(reader_user) }

    it 'returns state field for all users' do
      get "/v3/stacks/#{deprecated_stack.guid}", nil, reader_headers

      expect(last_response.status).to eq(200)
      expect(parsed_response['state']).to eq('DEPRECATED')
    end
  end

  describe 'GET /v3/stacks' do
    before { VCAP::CloudController::Stack.dataset.destroy }

    let!(:active_stack) { VCAP::CloudController::Stack.make(name: 'active', state: 'ACTIVE') }
    let!(:deprecated_stack) { VCAP::CloudController::Stack.make(name: 'deprecated', state: 'DEPRECATED') }
    let!(:restricted_stack) { VCAP::CloudController::Stack.make(name: 'restricted', state: 'RESTRICTED') }
    let!(:disabled_stack) { VCAP::CloudController::Stack.make(name: 'disabled', state: 'DISABLED') }

    let(:reader_user) { make_user }
    let(:reader_headers) { headers_for(reader_user) }

    it 'includes state for all stacks' do
      get '/v3/stacks', nil, reader_headers

      expect(last_response.status).to eq(200)

      resources = parsed_response['resources']
      expect(resources.pluck('state')).to contain_exactly('ACTIVE', 'DEPRECATED', 'RESTRICTED', 'DISABLED')
    end
  end
end
