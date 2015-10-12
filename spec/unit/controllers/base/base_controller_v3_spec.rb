require 'rails_helper'

module VCAP
  module CloudController
    module RestController
      describe BaseControllerV3, type: :controller do
        RSpec::Matchers.define_negated_matcher :not_change, :change

        controller do
          def index
            head 204
          end

          def show
            head 204
          end

          def create
            head 204
          end
        end

        describe 'auth token validation' do
          context 'when a valid auth is provided' do
            let(:headers) { headers_for(User.new(guid: expected_user_id)) }
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
              expect { get :index }.to raise_error(VCAP::Errors::ApiError).
                and not_change { VCAP::CloudController::SecurityContext.current_user }.from(nil).
                and change { VCAP::CloudController::SecurityContext.token }.to(:invalid_token)

            end
          end

          context 'when there is no auth token provided' do
            it 'sets security context to be empty' do
              expect { get :index }.to raise_error(VCAP::Errors::ApiError).
                and not_change { VCAP::CloudController::SecurityContext.current_user }.from(nil).
                and not_change { VCAP::CloudController::SecurityContext.token }.from(nil)
            end
          end
        end

        describe 'read permission scope validation' do
          let(:headers) { headers_for(User.new(guid: 'some-guid'), scopes: ['cloud_controller.write']) }

          before do
            @request.env.merge!(headers)
          end

          it 'is required on index' do
            expect {
              get :index
            }.to raise_error(VCAP::Errors::ApiError, 'You are not authorized to perform the requested action')
          end

          it 'is required on show' do
            expect {
              get :show, id: 1
            }.to raise_error(VCAP::Errors::ApiError, 'You are not authorized to perform the requested action')
          end

          it 'is not required on other actions' do
              expect {
                post :create
              }.not_to raise_error
          end

          it 'is not required for admin' do
            @request.env.merge!(admin_headers)

            expect {
              post :create
            }.not_to raise_error
          end
        end

        describe 'write permission scope validation' do
          let(:headers) { headers_for(User.new(guid: 'some-guid'), scopes: ['cloud_controller.read']) }

          before do
            @request.env.merge!(headers)
          end

          it 'is not required on index' do
            expect {
              get :index
            }.not_to raise_error
          end

          it 'is not required on show' do
            expect {
              get :show, id: 1
            }.not_to raise_error
          end

          it 'is required on other actions' do
            expect {
              post :create
            }.to raise_error(VCAP::Errors::ApiError, 'You are not authorized to perform the requested action')
          end

          it 'is not required for admin' do
            @request.env.merge!(admin_headers)

            expect {
              post :create
            }.not_to raise_error
          end
        end
      end
    end
  end
end
