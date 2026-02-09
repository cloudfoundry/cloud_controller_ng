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

    context 'when creating stack with state_reason' do
      it 'creates stack with state_reason' do
        request_body = {
          name: 'deprecated-with-reason',
          state: 'DEPRECATED',
          state_reason: 'This stack will be removed on 2026-12-31'
        }.to_json

        post '/v3/stacks', request_body, headers

        expect(last_response.status).to eq(201)
        expect(parsed_response['state']).to eq('DEPRECATED')
        expect(parsed_response['state_reason']).to eq('This stack will be removed on 2026-12-31')
      end

      it 'creates stack without state_reason' do
        request_body = {
          name: 'active-no-reason',
          state: 'ACTIVE'
        }.to_json

        post '/v3/stacks', request_body, headers

        expect(last_response.status).to eq(201)
        expect(parsed_response['state']).to eq('ACTIVE')
        expect(parsed_response['state_reason']).to be_nil
      end

      it 'rejects state_reason exceeding maximum length' do
        request_body = {
          name: 'long-reason-stack',
          state: 'DEPRECATED',
          state_reason: 'A' * 5001
        }.to_json

        post '/v3/stacks', request_body, headers

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'].first['detail']).to include('is too long')
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

    context 'when creating stack with null state' do
      it 'returns validation error' do
        request_body = {
          name: 'stack-null-state',
          state: nil
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

    context 'when updating state_reason' do
      it 'updates state_reason along with state' do
        request_body = {
          state: 'DEPRECATED',
          state_reason: 'Stack will be removed on 2026-12-31'
        }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state']).to eq('DEPRECATED')
        expect(parsed_response['state_reason']).to eq('Stack will be removed on 2026-12-31')

        stack.reload
        expect(stack.state_reason).to eq('Stack will be removed on 2026-12-31')
      end

      it 'updates state_reason independently' do
        stack.update(state: 'DEPRECATED')

        request_body = {
          state_reason: 'Updated reason for deprecation'
        }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state']).to eq('DEPRECATED')
        expect(parsed_response['state_reason']).to eq('Updated reason for deprecation')
      end

      it 'clears state_reason when set to null' do
        stack.update(state: 'DEPRECATED', state_reason: 'Initial reason')

        request_body = {
          state_reason: nil
        }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state_reason']).to be_nil

        stack.reload
        expect(stack.state_reason).to be_nil
      end

      it 'preserves state_reason when not included in request' do
        stack.update(state: 'DEPRECATED', state_reason: 'Existing reason')

        request_body = {
          state: 'RESTRICTED'
        }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state']).to eq('RESTRICTED')
        expect(parsed_response['state_reason']).to eq('Existing reason')
      end

      it 'rejects state_reason exceeding maximum length' do
        request_body = {
          state_reason: 'A' * 5001
        }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'].first['detail']).to include('is too long')
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

    context 'when stack has state_reason' do
      let!(:stack_with_reason) do
        VCAP::CloudController::Stack.make(
          state: 'DEPRECATED',
          state_reason: 'EOL on 2026-12-31'
        )
      end

      it 'returns state_reason in response' do
        get "/v3/stacks/#{stack_with_reason.guid}", nil, reader_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state']).to eq('DEPRECATED')
        expect(parsed_response['state_reason']).to eq('EOL on 2026-12-31')
      end
    end

    context 'when stack has no state_reason' do
      let!(:stack_without_reason) do
        VCAP::CloudController::Stack.make(state: 'ACTIVE', state_reason: nil)
      end

      it 'returns null state_reason in response' do
        get "/v3/stacks/#{stack_without_reason.guid}", nil, reader_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['state']).to eq('ACTIVE')
        expect(parsed_response['state_reason']).to be_nil
      end
    end
  end

  describe 'GET /v3/stacks' do
    before { VCAP::CloudController::Stack.dataset.destroy }

    let!(:active_stack) { VCAP::CloudController::Stack.make(name: 'active', state: 'ACTIVE') }
    let!(:deprecated_stack) { VCAP::CloudController::Stack.make(name: 'deprecated', state: 'DEPRECATED', state_reason: 'Deprecated reason') }
    let!(:restricted_stack) { VCAP::CloudController::Stack.make(name: 'restricted', state: 'RESTRICTED') }
    let!(:disabled_stack) { VCAP::CloudController::Stack.make(name: 'disabled', state: 'DISABLED', state_reason: 'Disabled reason') }

    let(:reader_user) { make_user }
    let(:reader_headers) { headers_for(reader_user) }

    it 'includes state for all stacks' do
      get '/v3/stacks', nil, reader_headers

      expect(last_response.status).to eq(200)

      resources = parsed_response['resources']
      expect(resources.pluck('state')).to contain_exactly('ACTIVE', 'DEPRECATED', 'RESTRICTED', 'DISABLED')
    end

    it 'includes state_reason for stacks that have it' do
      get '/v3/stacks', nil, reader_headers

      expect(last_response.status).to eq(200)

      resources = parsed_response['resources']

      deprecated = resources.find { |r| r['name'] == 'deprecated' }
      expect(deprecated['state_reason']).to eq('Deprecated reason')

      disabled = resources.find { |r| r['name'] == 'disabled' }
      expect(disabled['state_reason']).to eq('Disabled reason')

      active = resources.find { |r| r['name'] == 'active' }
      expect(active['state_reason']).to be_nil

      restricted = resources.find { |r| r['name'] == 'restricted' }
      expect(restricted['state_reason']).to be_nil
    end
  end
end
