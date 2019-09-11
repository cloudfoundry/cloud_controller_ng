require 'spec_helper'
require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
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

    def read_access
      render status: 200, json: can_read_from_space?(params[:space_guid], params[:org_guid])
    end

    def write_to_org_access
      render status: 200, json: can_write_to_org?(params[:org_guid])
    end

    def read_from_org_access
      render status: 200, json: can_read_from_org?(params[:org_guid])
    end

    def secret_access
      render status: 200, json: can_read_secrets_in_space?(VCAP::CloudController::Space.find(guid: params[:space_guid]))
    end

    def write_globally_access
      render status: 200, json: can_write_globally?
    end

    def read_globally_access
      render status: 200, json: can_read_globally?
    end

    def isolation_segment_read_access
      render status: 200, json: can_read_from_isolation_segment?(VCAP::CloudController::IsolationSegmentModel.find(guid: params[:iso_seg]))
    end

    def write_access
      render status: 200, json: can_write_to_space?(params[:space_guid])
    end

    def api_explode
      raise CloudController::Errors::ApiError.new_from_details('InvalidRequest', 'omg no!')
    end

    def compound_error
      raise CloudController::Errors::CompoundError.new [
        CloudController::Errors::ApiError.new_from_details('InvalidRequest', 'error1'),
        CloudController::Errors::ApiError.new_from_details('InvalidRequest', 'error2'),
      ]
    end

    def blobstore_error
      raise CloudController::Blobstore::BlobstoreError.new('it broke!')
    end

    def not_found
      raise CloudController::Errors::NotFound.new_from_details('NotFound')
    end

    def yaml_rejection
      render status: 200, body: params[:body]
    end

    def warnings_is_nil
      add_warning_headers(nil)
      render status: 200, json: {}
    end

    def multiple_warnings
      add_warning_headers(['warning,a', 'wa,rning b', '!@#$%^&*(),:|{}+=-<>'])
      render status: 200, json: {}
    end

    def warnings_incorrect_type
      add_warning_headers('value of incorrect type')
      render status: 200, json: {}
    end
  end

  let(:perm_client) { instance_double(VCAP::CloudController::Perm::Client) }

  before do
    Scientist::Observation::RESCUES.replace []

    perm_config = TestConfig.config[:perm]
    perm_config[:enabled] = true
    TestConfig.override(perm: perm_config)

    allow(VCAP::CloudController::Perm::Client).to receive(:new).and_return(perm_client)
  end

  describe '#check_read_permissions' do
    before do
      set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: [])
    end

    it 'is required on index' do
      get :index

      expect(response.status).to eq(403)
      expect(response).to have_error_message('You are not authorized to perform the requested action')
    end

    it 'is required on show' do
      get :show, params: { id: 1 }

      expect(response.status).to eq(403)
      expect(response).to have_error_message('You are not authorized to perform the requested action')
    end

    context 'cloud_controller.read' do
      before do
        set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: ['cloud_controller.read'])
      end

      it 'grants reading access' do
        get :index
        expect(response.status).to eq(200)
      end

      it 'should show a specific item' do
        get :show, params: { id: 1 }
        expect(response.status).to eq(204)
      end
    end

    context 'cloud_controller.admin_read_only' do
      before do
        set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: ['cloud_controller.admin_read_only'])
      end

      it 'grants reading access' do
        get :index
        expect(response.status).to eq(200)
      end

      it 'should show a specific item' do
        get :show, params: { id: 1 }
        expect(response.status).to eq(204)
      end
    end

    context 'cloud_controller.global_auditor' do
      before do
        set_current_user_as_global_auditor
      end

      it 'grants reading access' do
        get :index
        expect(response.status).to eq(200)
      end

      it 'should show a specific item' do
        get :show, params: { id: 1 }
        expect(response.status).to eq(204)
      end
    end

    it 'admin can read all' do
      set_current_user_as_admin

      get :show, params: { id: 1 }
      expect(response.status).to eq(204)

      get :index
      expect(response.status).to eq(200)
    end

    context 'post' do
      before do
        set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: ['cloud_controller.write'])
      end

      it 'is not required on other actions' do
        post :create

        expect(response.status).to eq(201)
      end
    end
  end

  describe 'when a user does not have cloud_controller.write scope' do
    before do
      set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: ['cloud_controller.read'])
    end

    it 'is not required on index' do
      get :index
      expect(response.status).to eq(200)
    end

    it 'is not required on show' do
      get :show, params: { id: 1 }
      expect(response.status).to eq(204)
    end

    it 'is required on other actions' do
      post :create
      expect(response.status).to eq(403)
      expect(response).to have_error_message('You are not authorized to perform the requested action')
    end

    it 'is not required for admin' do
      set_current_user_as_admin

      post :create
      expect(response.status).to eq(201)
    end
  end

  describe 'auth token validation' do
    context 'when the token contains a valid user' do
      before do
        set_current_user_as_admin
      end

      it 'allows the operation' do
        get :index
        expect(response.status).to eq(200)
      end
    end

    context 'when there is no token' do
      it 'raises NotAuthenticated' do
        get :index
        expect(response.status).to eq(401)
        expect(response).to have_error_message('Authentication error')
      end
    end

    context 'when the token is invalid' do
      before do
        VCAP::CloudController::SecurityContext.set(nil, :invalid_token, nil)
      end

      it 'raises InvalidAuthToken' do
        get :index
        expect(response.status).to eq(401)
        expect(response).to have_error_message('Invalid Auth Token')
      end
    end

    context 'when there is a token but no matching user' do
      before do
        user = nil
        VCAP::CloudController::SecurityContext.set(user, 'valid_token', nil)
      end

      it 'raises InvalidAuthToken' do
        get :index
        expect(response.status).to eq(401)
        expect(response).to have_error_message('Invalid Auth Token')
      end
    end
  end

  describe '#handle_blobstore_error' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'rescues from ApiError and renders an error presenter' do
      allow_any_instance_of(ErrorPresenter).to receive(:raise_500?).and_return(false)
      routes.draw { get 'blobstore_error' => 'anonymous#blobstore_error' }
      get :blobstore_error
      expect(response.status).to eq(500)
      expect(response).to have_error_message(/three retries/)
    end
  end

  describe '#handle_api_error' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'rescues from ApiError and renders an error presenter' do
      routes.draw { get 'api_explode' => 'anonymous#api_explode' }
      get :api_explode
      expect(response.status).to eq(400)
      expect(response).to have_error_message('The request is invalid')
    end
  end

  describe '#handle_compound_error' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'rescues from CompoundErrors and renders an error presenter' do
      routes.draw { get 'compound_error' => 'anonymous#compound_error' }
      get :compound_error
      expect(response.status).to eq(400)
      expect(parsed_body['errors'].length).to eq 2
    end
  end

  describe '#handle_not_found' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'rescues from NotFound error and renders an error presenter' do
      routes.draw { get 'not_found' => 'anonymous#not_found' }
      get :not_found
      expect(response.status).to eq(404)
      expect(response).to have_error_message('Unknown request')
    end
  end

  describe '#add_warning_headers' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'does nothing when warnings is nil' do
      routes.draw { get 'warnings_is_nil' => 'anonymous#warnings_is_nil' }
      get :warnings_is_nil
      expect(response.status).to eq(200)
      expect(response.headers['X-Cf-Warnings']).to be(nil)
    end

    it 'throws argument error when warnings is not an array' do
      routes.draw { get 'warnings_incorrect_type' => 'anonymous#warnings_incorrect_type' }
      expect do
        get :warnings_incorrect_type
      end.to raise_error(ArgumentError)
    end

    it 'does nothing when warnings is nil' do
      routes.draw { get 'multiple_warnings' => 'anonymous#multiple_warnings' }
      get :multiple_warnings
      expect(response.status).to eq(200)
      warnings = response.headers['X-Cf-Warnings'].split(',').map { |w| CGI.unescape(w) }
      expect(warnings).to eq([
        'warning,a',
        'wa,rning b',
        '!@#$%^&*(),:|{}+=-<>',
      ])
    end
  end
end
