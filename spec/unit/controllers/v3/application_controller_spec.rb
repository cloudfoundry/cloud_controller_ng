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
      can_read?(params[:space_guid], params[:org_guid])
      head 200
    end

    def secret_access
      can_see_secrets?(VCAP::CloudController::Space.find(guid: params[:space_guid]))
      head 200
    end

    def read_globally_access
      can_read_globally?
      head 200
    end

    def isolation_segment_read_access
      can_read_from_isolation_segment?(VCAP::CloudController::IsolationSegmentModel.find(guid: params[:iso_seg]))
      head 200
    end

    def write_access
      can_write?(params[:space_guid])
      head 200
    end

    def api_explode
      raise CloudController::Errors::ApiError.new_from_details('InvalidRequest', 'omg no!')
    end

    def blobstore_error
      raise CloudController::Blobstore::BlobstoreError.new('it broke!')
    end

    def not_found
      raise CloudController::Errors::NotFound.new_from_details('NotFound')
    end
  end

  describe '#check_read_permissions' do
    before do
      set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: [])
    end

    it 'is required on index' do
      get :index

      expect(response.status).to eq(403)
      expect(parsed_body['errors'].first['detail']).to eq('You are not authorized to perform the requested action')
    end

    it 'is required on show' do
      get :show, id: 1

      expect(response.status).to eq(403)
      expect(parsed_body['errors'].first['detail']).to eq('You are not authorized to perform the requested action')
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
        get :show, id: 1
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
        get :show, id: 1
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
        get :show, id: 1
        expect(response.status).to eq(204)
      end
    end

    it 'admin can read all' do
      set_current_user_as_admin

      get :show, id: 1
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
      get :show, id: 1
      expect(response.status).to eq(204)
    end

    it 'is required on other actions' do
      post :create
      expect(response.status).to eq(403)
      expect(parsed_body['errors'].first['detail']).to eq('You are not authorized to perform the requested action')
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
        expect(parsed_body['errors'].first['detail']).to eq('Authentication error')
      end
    end

    context 'when the token is invalid' do
      before do
        VCAP::CloudController::SecurityContext.set(nil, :invalid_token, nil)
      end

      it 'raises InvalidAuthToken' do
        get :index
        expect(response.status).to eq(401)
        expect(parsed_body['errors'].first['detail']).to eq('Invalid Auth Token')
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
        expect(parsed_body['errors'].first['detail']).to eq('Invalid Auth Token')
      end
    end
  end

  describe '#can_read?' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'asks for #can_read_from_space? on behalf of the current user' do
      routes.draw { get 'read_access' => 'anonymous#read_access' }

      permissions = instance_double(VCAP::CloudController::Permissions, can_read_from_space?: true)
      allow(VCAP::CloudController::Permissions).to receive(:new).and_return(permissions)

      get :read_access, space_guid: 'space-guid', org_guid: 'org-guid'

      expect(permissions).to have_received(:can_read_from_space?).with('space-guid', 'org-guid')
    end
  end

  describe '#can_see_secrets?' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'asks for #can_see_secrets_in_space? on behalf of the current user' do
      routes.draw { get 'secret_access' => 'anonymous#secret_access' }

      space = VCAP::CloudController::Space.make
      permissions = instance_double(VCAP::CloudController::Permissions, can_see_secrets_in_space?: true)
      allow(VCAP::CloudController::Permissions).to receive(:new).and_return(permissions)

      get :secret_access, space_guid: space.guid

      expect(permissions).to have_received(:can_see_secrets_in_space?).with(space.guid, space.organization_guid)
    end
  end

  describe '#can_read_globally?' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'asks for #can_read_globally? on behalf of the current user' do
      routes.draw { get 'read_globally_access' => 'anonymous#read_globally_access' }

      permissions = instance_double(VCAP::CloudController::Permissions, can_read_globally?: true)
      allow(VCAP::CloudController::Permissions).to receive(:new).and_return(permissions)

      get :read_globally_access

      expect(permissions).to have_received(:can_read_globally?)
    end
  end

  describe '#can_read_from_isolation_segment?' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'asks for #can_read_from_isolation_segment? on behalf of the current user' do
      routes.draw { get 'isolation_segment_read_access' => 'anonymous#isolation_segment_read_access' }

      iso_seg = VCAP::CloudController::IsolationSegmentModel.make
      permissions = instance_double(VCAP::CloudController::Permissions, can_read_from_isolation_segment?: true)
      allow(VCAP::CloudController::Permissions).to receive(:new).and_return(permissions)

      get :isolation_segment_read_access, iso_seg: iso_seg.guid

      expect(permissions).to have_received(:can_read_from_isolation_segment?).with(iso_seg)
    end
  end

  describe '#can_write?' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'asks for #can_read_from_space? on behalf of the current user' do
      routes.draw { get 'write_access' => 'anonymous#write_access' }

      permissions = instance_double(VCAP::CloudController::Permissions, can_write_to_space?: true)
      allow(VCAP::CloudController::Permissions).to receive(:new).and_return(permissions)

      get :write_access, space_guid: 'space-guid', org_guid: 'org-guid'

      expect(permissions).to have_received(:can_write_to_space?).with('space-guid')
    end
  end

  describe '#handle_blobstore_error' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'rescues from ApiError and renders an error presenter' do
      routes.draw { get 'blobstore_error' => 'anonymous#blobstore_error' }
      get :blobstore_error
      expect(response.status).to eq(500)
      expect(parsed_body['errors'].first['detail']).to match /three retries/
    end
  end

  describe '#handle_api_error' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'rescues from ApiError and renders an error presenter' do
      routes.draw { get 'api_explode' => 'anonymous#api_explode' }
      get :api_explode
      expect(response.status).to eq(400)
      expect(parsed_body['errors'].first['detail']).to eq('The request is invalid')
    end
  end

  describe '#handle_not_found' do
    let!(:user) { set_current_user(VCAP::CloudController::User.make) }

    it 'rescues from NotFound error and renders an error presenter' do
      routes.draw { get 'not_found' => 'anonymous#not_found' }
      get :not_found
      expect(response.status).to eq(404)
      expect(parsed_body['errors'].first['detail']).to eq('Unknown request')
    end
  end
end
