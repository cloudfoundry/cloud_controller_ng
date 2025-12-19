require 'spec_helper'
require 'rails_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

RSpec.describe ApplicationController, type: :controller do
  RSpec::Matchers.define_negated_matcher :not_change, :change

  controller do
    def index
      render 200, json: { request_id: VCAP::Request.current_id }
    end

    def show
      head :no_content
    end

    def create
      head :created
    end

    def api_explode
      raise CloudController::Errors::ApiError.new_from_details('InvalidRequest', 'omg no!')
    end

    def compound_error
      raise CloudController::Errors::CompoundError.new [
        CloudController::Errors::ApiError.new_from_details('InvalidRequest', 'error1'),
        CloudController::Errors::ApiError.new_from_details('InvalidRequest', 'error2')
      ]
    end

    def blobstore_error
      raise CloudController::Blobstore::BlobstoreError.new('it broke!')
    end

    def not_found
      raise CloudController::Errors::NotFound.new_from_details('NotFound')
    end

    def key_derivation_error
      raise VCAP::CloudController::Encryptor::EncryptorError
    end

    def db_disconnect_error
      raise Sequel::DatabaseDisconnectError.new
    end

    def db_connection_error
      raise Sequel::DatabaseConnectionError.new
    end

    def warnings_is_nil
      add_warning_headers(nil)
      render status: :ok, json: {}
    end

    def multiple_warnings
      add_warning_headers(['warning,a', 'wa,rning b', '!@#$%^&*(),:|{}+=-<>'])
      render status: :ok, json: {}
    end

    def warnings_incorrect_type
      add_warning_headers('value of incorrect type')
      render status: :ok, json: {}
    end
  end

  describe '#check_read_permissions' do
    before do
      set_current_user(VCAP::CloudController::User.make, scopes: [])
    end

    it 'is required on index' do
      get :index

      expect(response).to have_http_status(:forbidden)
      expect(response).to have_error_message('You are not authorized to perform the requested action')
    end

    it 'is required on show' do
      get :show, params: { id: 1 }

      expect(response).to have_http_status(:forbidden)
      expect(response).to have_error_message('You are not authorized to perform the requested action')
    end

    context 'cloud_controller.read' do
      before do
        set_current_user_as_reader
      end

      it 'grants reading access' do
        get :index
        expect(response).to have_http_status(:ok)
      end

      it 'shows a specific item' do
        get :show, params: { id: 1 }
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'cloud_controller.admin_read_only' do
      before do
        set_current_user_as_admin_read_only
      end

      it 'grants reading access' do
        get :index
        expect(response).to have_http_status(:ok)
      end

      it 'shows a specific item' do
        get :show, params: { id: 1 }
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'cloud_controller.global_auditor' do
      before do
        set_current_user_as_global_auditor
      end

      it 'grants reading access' do
        get :index
        expect(response).to have_http_status(:ok)
      end

      it 'shows a specific item' do
        get :show, params: { id: 1 }
        expect(response).to have_http_status(:no_content)
      end
    end

    it 'admin can read all' do
      set_current_user_as_admin

      get :show, params: { id: 1 }
      expect(response).to have_http_status(:no_content)

      get :index
      expect(response).to have_http_status(:ok)
    end

    context 'post' do
      before do
        set_current_user_as_writer
      end

      it 'is not required on other actions' do
        post :create

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'when a user has the cloud_controller_service_permissions.read scope' do
    before do
      set_current_user_as_service_permissions_reader
    end

    it 'cannot index' do
      get :index
      expect(response).to have_http_status(:forbidden)
      expect(response).to have_error_message('You are not authorized to perform the requested action')
    end

    it 'cannot show' do
      get :show, params: { id: 1 }
      expect(response).to have_http_status(:forbidden)
      expect(response).to have_error_message('You are not authorized to perform the requested action')
    end

    it 'cannot create' do
      post :create
      expect(response).to have_http_status(:forbidden)
      expect(response).to have_error_message('You are not authorized to perform the requested action')
    end
  end

  describe 'when a user does not have cloud_controller.write scope' do
    before do
      set_current_user_as_reader
    end

    it 'is not required on index' do
      get :index
      expect(response).to have_http_status(:ok)
    end

    it 'is not required on show' do
      get :show, params: { id: 1 }
      expect(response).to have_http_status(:no_content)
    end

    it 'is required on other actions' do
      post :create
      expect(response).to have_http_status(:forbidden)
      expect(response).to have_error_message('You are not authorized to perform the requested action')
    end

    it 'is not required for admin' do
      set_current_user_as_admin

      post :create
      expect(response).to have_http_status(:created)
    end
  end

  describe 'auth token validation' do
    context 'when the token contains a valid user' do
      before do
        set_current_user_as_admin
      end

      it 'allows the operation' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when there is no token' do
      it 'raises NotAuthenticated' do
        get :index
        expect(response).to have_http_status(:unauthorized)
        expect(response).to have_error_message('Authentication error')
      end
    end

    context 'when the token is invalid' do
      before do
        VCAP::CloudController::SecurityContext.set(nil, :invalid_token, nil)
      end

      it 'raises InvalidAuthToken' do
        get :index
        expect(response).to have_http_status(:unauthorized)
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
        expect(response).to have_http_status(:unauthorized)
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
      expect(response).to have_http_status(:internal_server_error)
      expect(response).to have_error_message(/three retries/)
    end
  end

  describe '#handle_api_error' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'rescues from ApiError and renders an error presenter' do
      routes.draw { get 'api_explode' => 'anonymous#api_explode' }
      get :api_explode
      expect(response).to have_http_status(:bad_request)
      expect(response).to have_error_message('The request is invalid')
    end
  end

  describe '#handle_compound_error' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'rescues from CompoundErrors and renders an error presenter' do
      routes.draw { get 'compound_error' => 'anonymous#compound_error' }
      get :compound_error
      expect(response).to have_http_status(:bad_request)
      expect(parsed_body['errors'].length).to eq 2
    end
  end

  describe '#handle_not_found' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'rescues from NotFound error and renders an error presenter' do
      routes.draw { get 'not_found' => 'anonymous#not_found' }
      get :not_found
      expect(response).to have_http_status(:not_found)
      expect(response).to have_error_message('Unknown request')
    end
  end

  describe '#handle_db_connection_error' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_any_instance_of(ErrorPresenter).to receive(:raise_500?).and_return(false)
      routes.draw do
        get 'db_connection_error' => 'anonymous#db_connection_error'
        get 'db_disconnect_error' => 'anonymous#db_disconnect_error'
      end
    end

    it 'rescues from Sequel::DatabaseConnectionError and renders an error presenter' do
      get :db_connection_error
      expect(response).to have_http_status(:service_unavailable)
      expect(response).to have_error_message(/Database connection failure/)
    end

    it 'rescues from Sequel::DatabaseDisconnectError and renders an error presenter' do
      get :db_disconnect_error
      expect(response).to have_http_status(:service_unavailable)
      expect(response).to have_error_message(/Database connection failure/)
    end
  end

  describe '#handle_key_derivation_error' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_any_instance_of(ErrorPresenter).to receive(:raise_500?).and_return(false)
      routes.draw do
        get 'key_derivation_error' => 'anonymous#key_derivation_error'
      end
    end

    it 'rescues from EncryptorError and renders an error presenter' do
      get :key_derivation_error
      expect(response).to have_http_status(:internal_server_error)
      expect(response).to have_error_message(/Error while processing encrypted data/)
    end
  end

  describe '#add_warning_headers' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'does nothing when warnings is nil' do
      routes.draw { get 'warnings_is_nil' => 'anonymous#warnings_is_nil' }
      get :warnings_is_nil
      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Cf-Warnings']).to be_nil
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
      expect(response).to have_http_status(:ok)
      warnings = response.headers['X-Cf-Warnings'].map { |w| CGI.unescape(w) }
      expect(warnings).to eq([
        'warning,a',
        'wa,rning b',
        '!@#$%^&*(),:|{}+=-<>'
      ])
    end
  end
end
