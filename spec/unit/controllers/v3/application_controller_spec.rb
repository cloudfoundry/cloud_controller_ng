require 'rails_helper'

describe ApplicationController, type: :controller do
  RSpec::Matchers.define_negated_matcher :not_change, :change

  controller do
    def index
      render 200, json: { request_id: VCAP::Request.current_id }
    end

    def show
      head 204
    end

    def create
      head 201
    end
  end

  describe 'setting the current user' do
    context 'when a valid auth is provided' do
      let(:headers) { headers_for(VCAP::CloudController::User.new(guid: expected_user_id)) }
      let(:expected_user_id) { 'user-id' }

      before do
        @request.env.merge!(headers)
      end

      it 'sets security context to the user' do
        get :index

        expect(VCAP::CloudController::SecurityContext.current_user).to eq VCAP::CloudController::User.last
        expect(VCAP::CloudController::SecurityContext.token['user_id']).to eq expected_user_id
      end
    end

    context 'when an invalid auth token is provided' do
      before do
        @request.env.merge!('HTTP_AUTHORIZATION' => 'bearer potato')
      end

      it 'sets the token to invalid' do
        expect { get :index }.to not_change { VCAP::CloudController::SecurityContext.current_user }.from(nil).
          and change { VCAP::CloudController::SecurityContext.token }.to(:invalid_token)
      end
    end

    context 'when there is no auth token provided' do
      it 'sets security context to be empty' do
        expect { get :index }.to not_change { VCAP::CloudController::SecurityContext.current_user }.from(nil).
          and not_change { VCAP::CloudController::SecurityContext.token }.from(nil)
      end
    end
  end

  describe 'read permission scope validation' do
    let(:headers) { headers_for(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: ['cloud_controller.write']) }

    before do
      @request.env.merge!(headers)
    end

    it 'is required on index' do
      get :index

      expect(response.status).to eq(403)
      expect(MultiJson.load(response.body)['description']).to eq('You are not authorized to perform the requested action')
    end

    it 'is required on show' do
      get :show, id: 1

      expect(response.status).to eq(403)
      expect(MultiJson.load(response.body)['description']).to eq('You are not authorized to perform the requested action')
    end

    it 'is not required on other actions' do
      @request.env.merge!(json_headers({}))

      post :create
      expect(response.status).to eq(201)
    end

    it 'is not required for admin' do
      @request.env.merge!(json_headers(admin_headers))

      post :create
      expect(response.status).to eq(201)
    end
  end

  describe 'write permission scope validation' do
    let(:headers) { headers_for(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: ['cloud_controller.read']) }

    before do
      @request.env.merge!(headers)
    end

    it 'is not required on index' do
      get :index
      expect(response.status).to eq(200)
    end

    it 'is not required on show' do
      get :show, id: 1
      expect(response.status).to eq(204)
    end

    it 'is required on other actions' do
      post :create
      expect(response.status).to eq(403)
      expect(MultiJson.load(response.body)['description']).to eq('You are not authorized to perform the requested action')
    end

    it 'is not required for admin' do
      @request.env.merge!(json_headers(admin_headers))

      post :create
      expect(response.status).to eq(201)
    end
  end

  describe 'request id' do
    before do
      @request.env.merge!(admin_headers).merge!('cf.request_id' => 'expected-request-id')
    end

    it 'sets the vcap request current_id from the passed in rack request during request handling' do
      get :index

      # finding request id inside the controller action and returning on the body
      expect(MultiJson.load(response.body)['request_id']).to eq('expected-request-id')
    end

    it 'unsets the vcap request current_id after the request completes' do
      get :index
      expect(VCAP::Request.current_id).to be_nil
    end
  end

  describe 'https schema validation' do
    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      VCAP::CloudController::Config.config[:https_required] = true
    end

    context 'when request is http' do
      before do
        @request.env['rack.url_scheme'] = 'http'
      end

      it 'raises an error' do
        get :index
        expect(response.status).to eq(403)
        expect(MultiJson.load(response.body)['description']).to eq('You are not authorized to perform the requested action')
      end
    end

    context 'when request is https' do
      before do
        @request.env['rack.url_scheme'] = 'https'
      end

      it 'is a valid request' do
        get :index
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'auth token validation' do
    before do
      @request.env.merge!(headers)
    end

    context 'when the token contains a valid user' do
      let(:headers) { admin_headers }

      it 'allows the operation' do
        get :index
        expect(response.status).to eq(200)
      end
    end

    context 'when there is no token' do
      let(:headers) { {} }

      it 'raises NotAuthenticated' do
        get :index
        expect(response.status).to eq(401)
        expect(MultiJson.load(response.body)['description']).to eq('Authentication error')
      end
    end

    context 'when the token cannot be parsed' do
      let(:headers) { { 'HTTP_AUTHORIZATION' => 'bearer potato' } }

      it 'raises InvalidAuthToken' do
        get :index
        expect(response.status).to eq(401)
        expect(MultiJson.load(response.body)['description']).to eq('Invalid Auth Token')
      end
    end

    context 'when the token is valid but does not contain user or client id' do
      let(:headers) do
        coder = CF::UAA::TokenCoder.new(
          audience_ids: TestConfig.config[:uaa][:resource_id],
          skey:         TestConfig.config[:uaa][:symmetric_secret],
          pkey:         nil)

        token = coder.encode(scope: ['some-scope'])

        { 'HTTP_AUTHORIZATION' => "bearer #{token}" }
      end

      it 'raises InvalidAuthToken' do
        get :index
        expect(response.status).to eq(401)
        expect(MultiJson.load(response.body)['description']).to eq('Invalid Auth Token')
      end
    end
  end
end
