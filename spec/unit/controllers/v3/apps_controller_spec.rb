require 'rails_helper'
require 'permissions_spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

RSpec.describe AppsV3Controller, type: :controller do
  describe '#index' do
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user_as_admin(user:)
    end

    context 'query params' do
      context 'invalid param format' do
        it 'returns 400' do
          get :index, params: { order_by: '^=%' }, as: :json

          expect(response).to have_http_status :bad_request
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Order by can only be: 'created_at', 'updated_at', 'name'")
        end
      end

      context 'unknown query param' do
        it 'returns 400' do
          get :index, params: { meow: 'woof', kaplow: 'zoom' }, as: :json

          expect(response).to have_http_status :bad_request
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include('Unknown query parameter(s):')
          expect(response.body).to include('meow')
          expect(response.body).to include('kaplow')
        end
      end

      context 'invalid pagination' do
        it 'returns 400' do
          get :index, params: { per_page: 99_999_999_999_999_999 }, as: :json

          expect(response).to have_http_status :bad_request
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include 'Per page must be between'
        end
      end

      context 'invalid include' do
        it 'returns 400' do
          get :index, params: { include: 'juice' }, as: :json

          expect(response).to have_http_status :bad_request
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include "Invalid included resource: 'juice'"
        end
      end
    end

    context 'sorting' do
      before do
        VCAP::CloudController::AppModel.make(name: 'clem')
        VCAP::CloudController::AppModel.make(name: 'abel')
        VCAP::CloudController::AppModel.make(name: 'quartz')
        VCAP::CloudController::AppModel.make(name: 'beale')
        VCAP::CloudController::AppModel.make(name: 'rocky')
      end

      it 'sorts and paginates the apps by name' do
        get :index, params: { order_by: '+name', per_page: 2 }, as: :json

        expect(response.status).to eq(200), response.body
        response_names = parsed_body['resources'].pluck('name')
        expect(response_names).to match_array(%w[abel beale])
        expect(parsed_body['pagination']['next']['href']).to match(/order_by=%2Bname/)
        expect(parsed_body['pagination']['next']['href']).to match(/per_page=2/)
        expect(parsed_body['pagination']['next']['href']).to match(/page=2/)
      end

      it 'sorts and paginates the apps by name using the default direction only' do
        get :index, params: { order_by: '-name', per_page: 2 }, as: :json

        expect(response.status).to eq(200), response.body
        response_names = parsed_body['resources'].pluck('name')
        expect(response_names).to match_array(%w[quartz rocky])
        expect(parsed_body['pagination']['next']['href']).to match(/order_by=-name/)
        expect(parsed_body['pagination']['next']['href']).to match(/per_page=2/)
        expect(parsed_body['pagination']['next']['href']).to match(/page=2/)
      end

      it 'can get the first page descending' do
        get :index, params: { order_by: '-name', per_page: 2, page: 1 }, as: :json
        expect(response.status).to eq(200), response.body
        response_names = parsed_body['resources'].pluck('name')
        expect(response_names).to match_array(%w[rocky quartz])
        expect(parsed_body['pagination']['next']['href']).to match(/order_by=-name/)
        expect(parsed_body['pagination']['next']['href']).to match(/per_page=2/)
        expect(parsed_body['pagination']['next']['href']).to match(/page=2/)
        expect(parsed_body['pagination']['previous']).to be_nil
      end

      it 'can get the first page descending with a leading dash' do
        get :index, params: { order_by: '-name', per_page: 2, page: 1 }, as: :json
        expect(response.status).to eq(200), response.body
        response_names = parsed_body['resources'].pluck('name')
        expect(response_names).to match_array(%w[rocky quartz])
        expect(parsed_body['pagination']['next']['href']).to match(/order_by=-name/)
        expect(parsed_body['pagination']['next']['href']).to match(/per_page=2/)
        expect(parsed_body['pagination']['next']['href']).to match(/page=2/)
        expect(parsed_body['pagination']['previous']).to be_nil
      end

      it 'can get the second page descending' do
        get :index, params: { order_by: '-name', per_page: 2, page: 2 }, as: :json
        expect(response.status).to eq(200), response.body
        response_names = parsed_body['resources'].pluck('name')
        expect(response_names).to match_array(%w[clem beale])
        expect(parsed_body['pagination']['next']['href']).to match(/order_by=-name/)
        expect(parsed_body['pagination']['next']['href']).to match(/per_page=2/)
        expect(parsed_body['pagination']['next']['href']).to match(/page=3/)
        expect(parsed_body['pagination']['previous']['href']).to match(/order_by=-name/)
        expect(parsed_body['pagination']['previous']['href']).to match(/per_page=2/)
        expect(parsed_body['pagination']['previous']['href']).to match(/page=1/)
      end

      it 'can get the final page' do
        get :index, params: { order_by: '-name', per_page: 2, page: 3 }, as: :json
        expect(response.status).to eq(200), response.body
        response_names = parsed_body['resources'].pluck('name')
        expect(response_names).to match_array(%w[abel])
        expect(parsed_body['pagination']['next']).to be_nil
        expect(parsed_body['pagination']['previous']['href']).to match(/order_by=-name/)
        expect(parsed_body['pagination']['previous']['href']).to match(/per_page=2/)
        expect(parsed_body['pagination']['previous']['href']).to match(/page=2/)
      end
    end

    context 'label_selection' do
      it 'returns a 400 when the label_selector is invalid' do
        get :index, params: { label_selector: 'buncha nonsense' }

        expect(response).to have_http_status(:bad_request)

        expect(parsed_body['errors'].first['detail']).to match(/Invalid label_selector value/)
      end
    end
  end

  describe '#show' do
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
    end

    context 'when including an unrecognized query param' do
      it 'includes the space' do
        get :show, params: { guid: app_model.guid, include: :milk }

        expect(response).to have_http_status :bad_request
        expect(response.body).to match('Invalid included resource: \'milk\'')
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show, params: { guid: 'hahaha' }

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'permissions' do
      context 'when the user does not have cc read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'raises an ApiError with a 403 code' do
          get :show, params: { guid: app_model.guid }

          expect(response.body).to include 'NotAuthorized'
          expect(response).to have_http_status :forbidden
        end
      end
    end
  end

  describe '#create' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:request_body) do
      {
        name: 'some-name',
        relationships: { space: { data: { guid: space.guid } } },
        lifecycle: { type: 'buildpack', data: { buildpacks: ['http://some.url'], stack: nil } }
      }
    end

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space:)
    end

    it 'returns a 201 Created and the app' do
      post :create, params: request_body, as: :json

      app_model = space.app_models.last

      expect(response).to have_http_status :created
      expect(parsed_body['guid']).to eq(app_model.guid)
    end

    context 'when the request has invalid data' do
      let(:request_body) { { name: 'missing-all-other-required-fields' } }

      it 'returns an UnprocessableEntity error' do
        post :create, params: request_body, as: :json

        expect(response).to have_http_status :unprocessable_entity
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when the app is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::AppCreate).to receive(:create).
          and_raise(VCAP::CloudController::AppCreate::InvalidApp.new('ya done goofed'))
      end

      it 'returns an UnprocessableEntity error' do
        post :create, params: request_body, as: :json

        expect(response).to have_http_status :unprocessable_entity
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'ya done goofed'
      end
    end

    context 'metadata' do
      context 'when the label is invalid' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                'cloudfoundry.org/release' => 'stable'
              }
            }
          }
        end

        it 'returns an UnprocessableEntity error' do
          post :create, params: request_body, as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include 'UnprocessableEntity'
          expect(response).to have_error_message(/label [\w\s]+ error/)
        end
      end

      context 'when the annotation is invalid' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                'release' => 'stable'
              },
              annotations: {
                '' => 'uhoh'
              }
            }
          }
        end

        it 'returns an UnprocessableEntity error' do
          post :create, params: request_body, as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include 'UnprocessableEntity'
          expect(response).to have_error_message(/annotation [\w\s]+ error/)
        end
      end

      context 'when the metadata is valid' do
        let(:request_body) do
          {
            name: 'some-name',
            relationships: { space: { data: { guid: space.guid } } },
            metadata: {
              labels: {
                release: 'stable'
              },
              annotations: {
                this: 'is valid'
              }
            }
          }
        end

        it 'Returns a 201 and the app with metadata' do
          post :create, params: request_body, as: :json

          response_body = parsed_body
          response_metadata = response_body['metadata']

          expect(response).to have_http_status :created
          expect(response_metadata['labels']['release']).to eq 'stable'
          expect(response_metadata['annotations']['this']).to eq 'is valid'
        end
      end

      context 'when there are too many annotations' do
        let(:request_body) do
          {
            name: 'some-name',
            relationships: { space: { data: { guid: space.guid } } },
            metadata: {
              annotations: {
                radish: 'daikon',
                potato: 'idaho'
              }
            }
          }
        end

        before do
          VCAP::CloudController::Config.config.set(:max_annotations_per_resource, 1)
        end

        it 'responds with 422' do
          post :create, params: request_body, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to have_error_message(/exceed maximum of 1/)
        end
      end
    end

    context 'lifecycle data' do
      context 'when the space developer does not request a lifecycle' do
        let(:request_body) do
          {
            name: 'some-name',
            relationships: { space: { data: { guid: space.guid } } }
          }
        end

        it 'uses the defaults and returns a 201 and the app' do
          post :create, params: request_body, as: :json

          response_body = parsed_body
          lifecycle_data = response_body['lifecycle']['data']

          expect(response).to have_http_status :created
          expect(lifecycle_data['stack']).to eq VCAP::CloudController::Stack.default.name
          expect(lifecycle_data['buildpack']).to be_nil
        end
      end

      context 'buildpack' do
        context 'when the space developer requests lifecycle data' do
          context 'and leaves part of the data blank' do
            let(:request_body) do
              {
                name: 'some-name',
                relationships: { space: { data: { guid: space.guid } } },
                lifecycle: { type: 'buildpack', data: { stack: 'cflinuxfs4' } }
              }
            end

            it 'creates the app with the lifecycle data, filling in defaults' do
              post :create, params: request_body, as: :json

              response_body = parsed_body
              lifecycle_data = response_body['lifecycle']['data']

              expect(response).to have_http_status :created
              expect(lifecycle_data['stack']).to eq 'cflinuxfs4'
              expect(lifecycle_data['buildpack']).to be_nil
            end
          end

          context 'when the requested buildpack is not a valid url and is not a known buildpack' do
            let(:request_body) do
              {
                name: 'some-name',
                relationships: { space: { data: { guid: space.guid } } },
                lifecycle: { type: 'buildpack', data: { buildpacks: ['blawgow'], stack: nil } }
              }
            end

            it 'returns an UnprocessableEntity error' do
              post :create, params: request_body, as: :json

              expect(response).to have_http_status :unprocessable_entity
              expect(response.body).to include 'UnprocessableEntity'
              expect(response.body).to include 'must be an existing admin buildpack or a valid git URI'
            end
          end

          context 'and they do not include the data section' do
            let(:request_body) do
              {
                name: 'some-name',
                relationships: { space: { data: { guid: space.guid } } },
                lifecycle: { type: 'buildpack' }
              }
            end

            it 'raises an UnprocessableEntity error' do
              post :create, params: request_body, as: :json

              expect(response).to have_http_status(:unprocessable_entity)
              expect(response.body).to include 'UnprocessableEntity'
              expect(response.body).to include 'Lifecycle data must be an object'
            end
          end
        end
      end

      context 'docker' do
        context 'when lifecycle data is not empty' do
          let(:request_body) do
            {
              name: 'some-name',
              relationships: { space: { data: { guid: space.guid } } },
              lifecycle: { type: 'docker', data: { foo: 'bar' } }
            }
          end

          it 'raises an UnprocessableEntity error' do
            post :create, params: request_body, as: :json

            expect(response).to have_http_status(:unprocessable_entity)
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include "Lifecycle Unknown field(s): 'foo'"
          end
        end

        context 'when lifecycle data is not an object' do
          let(:request_body) do
            {
              name: 'some-name',
              relationships: { space: { data: { guid: space.guid } } },
              lifecycle: { type: 'docker', data: 'yay' }
            }
          end

          it 'raises an UnprocessableEntity error' do
            post :create, params: request_body, as: :json

            expect(response).to have_http_status(:unprocessable_entity)
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include 'Lifecycle data must be an object'
          end
        end
      end
    end

    context 'when the space does not exist' do
      before do
        request_body[:relationships][:space][:data][:guid] = 'made-up'
      end

      it 'returns an UnprocessableEntity error' do
        post :create, params: request_body, as: :json

        expect(response).to have_status_code(422)
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include('Invalid space. Ensure that the space exists and you have access to it.')
      end
    end

    context 'when requesting docker lifecycle and diego_docker feature flag is disabled' do
      let(:request_body) do
        {
          name: 'some-name',
          relationships: { space: { data: { guid: space.guid } } },
          lifecycle: { type: 'docker', data: {} }
        }
      end

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: false, error_message: nil)
      end

      context 'admin' do
        before do
          set_current_user_as_admin(user:)
        end

        it 'raises 403' do
          post :create, params: request_body, as: :json
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_docker')
        end
      end

      context 'non-admin' do
        it 'raises 403' do
          post :create, params: request_body, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_docker')
        end
      end
    end

    context 'when requesting cnb lifecycle and diego_cnb feature flag is disabled' do
      let(:request_body) do
        {
          name: 'some-name',
          relationships: { space: { data: { guid: space.guid } } },
          lifecycle: { type: 'cnb', data: {} }
        }
      end

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'diego_cnb', enabled: false, error_message: nil)
      end

      context 'admin' do
        before do
          set_current_user_as_admin(user:)
        end

        it 'raises 403' do
          post :create, params: request_body, as: :json
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_cnb')
        end
      end

      context 'non-admin' do
        it 'raises 403' do
          post :create, params: request_body, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_cnb')
        end
      end
    end
  end

  describe '#update' do
    let(:app_model) { VCAP::CloudController::AppModel.make(:buildpack) }

    let(:space) { app_model.space }
    let(:org) { space.organization }

    let(:request_body) { { name: 'new-name' } }

    before do
      user = VCAP::CloudController::User.make
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space:)
    end

    it 'returns a 200 OK and the app' do
      patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

      expect(response).to have_http_status :ok
      expect(parsed_body['guid']).to eq(app_model.guid)
      expect(parsed_body['name']).to eq('new-name')
    end

    context 'when the request has invalid data' do
      let(:request_body) { { name: false } }

      context 'when the app is invalid' do
        it 'returns an UnprocessableEntity error' do
          patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include 'UnprocessableEntity'
        end
      end
    end

    context 'lifecycle data' do
      let(:new_name) { 'potato' }

      before do
        VCAP::CloudController::Buildpack.make(name: 'some-buildpack-name')
        VCAP::CloudController::Buildpack.make(name: 'some-buildpack')
      end

      context 'when the space developer does not request lifecycle' do
        let(:request_body) do
          {
            name: new_name
          }
        end

        context 'for a buildpack app' do
          before do
            app_model.lifecycle_data.stack = 'some-stack-name'
            app_model.lifecycle_data.buildpacks = ['some-buildpack-name', 'http://buildpack.com']
            app_model.lifecycle_data.save
          end

          it 'uses the existing lifecycle on app' do
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json
            expect(response).to have_http_status :ok

            app_model.reload
            app_model.lifecycle_data.reload

            expect(app_model.name).to eq(new_name)
            expect(app_model.lifecycle_data.stack).to eq('some-stack-name')
            expect(app_model.lifecycle_data.buildpacks).to eq(['some-buildpack-name', 'http://buildpack.com'])
          end

          context 'when updating metadata' do
            context 'when the metadata is valid' do
              let(:request_body) do
                {
                  metadata: {
                    labels: {
                      release: 'stable'
                    }
                  }
                }
              end

              it 'updates the labels' do
                patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json
                expect(response).to have_http_status :ok

                app_model.reload

                expect(app_model.labels.length).to eq(1)
              end
            end

            context 'when the metadata is invalid' do
              let(:request_body) do
                {
                  metadata: {
                    labels: {
                      'cloudfoundry.org/release' => 'stable'
                    }
                  }
                }
              end

              it 'returns a 422' do
                patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json
                expect(response).to have_http_status :unprocessable_entity
                expect(response.body).to include 'UnprocessableEntity'
                expect(response.body).to match(/Metadata [\w\s]+ error/)
              end
            end
          end
        end

        context 'for a docker app' do
          let(:app_model) { VCAP::CloudController::AppModel.make(:docker) }

          it 'uses the existing lifecycle on app' do
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json
            expect(response).to have_http_status :ok

            app_model.reload

            expect(app_model.name).to eq(new_name)
            expect(app_model.lifecycle_type).to eq('docker')
          end
        end
      end

      context 'buildpack request' do
        context 'when the requested buildpack is not a valid url and is not a known buildpack' do
          let(:request_body) do
            {
              name: 'some-name',
              lifecycle: { type: 'buildpack', data: { buildpacks: ['blawgow'] } }
            }
          end

          it 'returns an UnprocessableEntity error' do
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

            expect(response).to have_http_status :unprocessable_entity
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('must be an existing admin buildpack or a valid git URI')
          end
        end

        context 'when the user specifies the buildpack' do
          let(:buildpack_url) { 'http://some.url' }
          let(:request_body) do
            { name: new_name,
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpacks: [buildpack_url]
                }
              } }
          end

          it 'sets the buildpack to the provided buildpack' do
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json
            expect(app_model.reload.lifecycle_data.buildpacks).to eq([buildpack_url])
          end
        end

        context 'when the user requests a nil buildpack' do
          let(:request_body) do
            { name: new_name,
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpacks: nil
                }
              } }
          end

          before do
            app_model.lifecycle_data.buildpacks = ['some-buildpack']
            app_model.lifecycle_data.save
          end

          it 'sets the buildpack to nil' do
            expect(app_model.lifecycle_data.buildpacks).not_to be_empty
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json
            expect(app_model.reload.lifecycle_data.buildpacks).to be_empty
          end
        end

        context 'when a user specifies a stack' do
          context 'when the requested stack is valid' do
            let(:request_body) do
              {
                name: new_name,
                lifecycle: {
                  type: 'buildpack',
                  data: {
                    stack: 'redhat'
                  }
                }
              }
            end

            before { VCAP::CloudController::Stack.create(name: 'redhat') }

            it 'sets the stack to the user provided stack' do
              patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json
              expect(app_model.lifecycle_data.stack).to eq('redhat')
            end
          end

          context 'when the requested stack is invalid' do
            let(:request_body) do
              {
                name: new_name,
                lifecycle: {
                  type: 'buildpack',
                  data: {
                    stack: 'stacks on stacks lol'
                  }
                }
              }
            end

            it 'returns an UnprocessableEntity error' do
              patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

              expect(response.body).to include 'UnprocessableEntity'
              expect(response).to have_http_status(:unprocessable_entity)
              expect(response.body).to include('Stack')
            end
          end
        end

        context 'when a user provides empty lifecycle data' do
          let(:request_body) do
            {
              name: new_name,
              lifecycle: {
                type: 'buildpack',
                data: {}
              }
            }
          end

          before do
            app_model.lifecycle_data.stack = VCAP::CloudController::Stack.default.name
            app_model.lifecycle_data.save
          end

          it 'does not modify the lifecycle data' do
            expect(app_model.lifecycle_data.stack).to eq VCAP::CloudController::Stack.default.name
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json
            expect(app_model.reload.lifecycle_data.stack).to eq VCAP::CloudController::Stack.default.name
          end
        end

        context 'when the space developer requests a lifecycle without a data key' do
          let(:request_body) do
            {
              name: 'some-name',
              lifecycle: { type: 'buildpack' }
            }
          end

          it 'raises an error' do
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

            expect(response).to have_http_status :unprocessable_entity
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('Lifecycle data must be an object')
          end
        end

        context 'when attempting to change to another lifecycle type' do
          let(:request_body) do
            {
              name: 'some-name',
              lifecycle: { type: 'docker', data: {} }
            }
          end

          it 'raises an error' do
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

            expect(response).to have_http_status :unprocessable_entity
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('Lifecycle type cannot be changed')
          end
        end
      end

      context 'docker request' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:docker) }

        context 'when attempting to change to another lifecycle type' do
          let(:request_body) do
            {
              name: 'some-name',
              lifecycle: { type: 'buildpack', data: {} }
            }
          end

          it 'raises an error' do
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

            expect(response).to have_http_status :unprocessable_entity
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('Lifecycle type cannot be changed')
          end
        end

        context 'when a user provides empty lifecycle data' do
          let(:request_body) do
            {
              name: 'some-name',
              lifecycle: {
                type: 'docker',
                data: {}
              }
            }
          end

          it 'does not fail' do
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json
            expect(response).to have_status_code(200)
          end
        end

        context 'when the space developer requests a lifecycle without a data key' do
          let(:request_body) do
            {
              name: 'some-name',
              lifecycle: { type: 'docker' }
            }
          end

          it 'raises an error' do
            patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

            expect(response).to have_http_status :unprocessable_entity
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('Lifecycle data must be an object')
          end
        end
      end
    end

    context 'metadata' do
      context 'when the label is invalid' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                'cloudfoundry.org/release' => 'stable'
              }
            }
          }
        end

        it 'returns an UnprocessableEntity error' do
          patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include 'UnprocessableEntity'
          expect(response).to have_error_message(/label [\w\s]+ error/)
        end
      end

      context 'when the annotation is invalid' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                'release' => 'stable'
              },
              annotations: {
                '' => 'uhoh'
              }
            }
          }
        end

        it 'returns an UnprocessableEntity error' do
          patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include 'UnprocessableEntity'
          expect(response).to have_error_message(/annotation [\w\s]+ error/)
        end
      end

      context 'when the metadata is valid' do
        let!(:app_annotation) do
          VCAP::CloudController::AppAnnotationModel.make(app: app_model, key_name: 'existing_anno', value: 'original-value')
        end

        let!(:delete_annotation) do
          VCAP::CloudController::AppAnnotationModel.make(app: app_model, key_name: 'please', value: 'delete me')
        end

        let(:request_body) do
          {
            name: 'some-name',
            metadata: {
              labels: {
                release: 'stable'
              },
              annotations: {
                new_anno: 'value',
                existing_anno: 'is valid',
                please: nil
              }
            }
          }
        end

        it 'Returns a 200 and the app with metadata' do
          patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

          response_body = parsed_body
          response_metadata = response_body['metadata']

          expect(response).to have_http_status(:ok)
          expect(response_metadata['labels']['release']).to eq 'stable'
          expect(response_metadata['annotations']['new_anno']).to eq 'value'
          expect(response_metadata['annotations']['existing_anno']).to eq 'is valid'
          expect(response_metadata['annotations']['please']).to be_nil
        end
      end

      context 'when there are too many annotations' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                radish: 'daikon',
                potato: 'idaho'
              }
            }
          }
        end

        before do
          VCAP::CloudController::Config.config.set(:max_annotations_per_resource, 1)
        end

        it 'responds with 422' do
          patch :update, params: { guid: app_model.guid }.merge(request_body), as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to have_error_message(/exceed maximum of 1/)
        end
      end
    end
  end

  describe '#destroy' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:app_delete_stub) { instance_double(VCAP::CloudController::AppDelete) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space:)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
      allow(VCAP::CloudController::Jobs::DeleteActionJob).to receive(:new).and_call_original
      allow(VCAP::CloudController::AppDelete).to receive(:new).and_return(app_delete_stub)
      allow(AppsV3Controller::DeleteAppErrorTranslatorJob).to receive(:new).and_call_original
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        delete :destroy, params: { guid: 'meowmeow' }

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    it 'successfully deletes the app in a background job' do
      delete :destroy, params: { guid: app_model.guid }

      app_delete_jobs = Delayed::Job.where(Sequel.lit("handler like '%AppDelete%'"))
      expect(app_delete_jobs.count).to eq 1
      app_delete_jobs.first

      expect(VCAP::CloudController::AppModel.find(guid: app_model.guid)).not_to be_nil
      expect(VCAP::CloudController::Jobs::DeleteActionJob).to have_received(:new).with(
        VCAP::CloudController::AppModel,
        app_model.guid,
        app_delete_stub
      )
      expect(AppsV3Controller::DeleteAppErrorTranslatorJob).to have_received(:new)
    end

    it 'creates a job to track the deletion and returns it in the location header' do
      expect do
        delete :destroy, params: { guid: app_model.guid }
      end.to change(VCAP::CloudController::PollableJobModel, :count).by(1)

      job = VCAP::CloudController::PollableJobModel.last
      enqueued_job = Delayed::Job.last
      expect(job.delayed_job_guid).to eq(enqueued_job.guid)
      expect(job.operation).to eq('app.delete')
      expect(job.state).to eq('PROCESSING')
      expect(job.resource_guid).to eq(app_model.guid)
      expect(job.resource_type).to eq('app')

      expect(response).to have_http_status(:accepted)
      expect(response.headers['Location']).to include "#{link_prefix}/v3/jobs/#{job.guid}"
    end
  end

  describe '#start' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(:buildpack, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:buildpack_lifecycle) { VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space:)
    end

    it 'returns a 200 and the app' do
      put :start, params: { guid: app_model.guid }, as: :json

      response_body = parsed_body

      expect(response).to have_http_status :ok
      expect(response_body['guid']).to eq(app_model.guid)
      expect(response_body['state']).to eq('STARTED')
    end

    context 'permissions' do
      context 'when the user does not have write permissions' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          put :start, params: { guid: app_model.guid }, as: :json

          response_body = parsed_body
          expect(response_body['errors'].first['title']).to eq 'CF-NotAuthorized'
          expect(response).to have_http_status :forbidden
        end
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space:)
        end

        it 'returns a 404 ResourceNotFound error' do
          put :start, params: { guid: app_model.guid }, as: :json

          response_body = parsed_body
          expect(response_body['errors'].first['title']).to eq 'CF-ResourceNotFound'
          expect(response).to have_http_status :not_found
        end
      end

      context 'when the user can read but cannot write to the app' do
        before do
          disallow_user_write_access(user, space:)
        end

        it 'raises ApiError NotAuthorized' do
          put :start, params: { guid: app_model.guid }, as: :json

          response_body = parsed_body
          expect(response_body['errors'].first['title']).to eq 'CF-NotAuthorized'
          expect(response).to have_http_status :forbidden
        end
      end
    end

    context 'when the app does not have a droplet' do
      before do
        droplet.destroy
      end

      it 'raises an API 422 error' do
        put :start, params: { guid: app_model.guid }, as: :json

        response_body = parsed_body
        expect(response_body['errors'].first['title']).to eq 'CF-UnprocessableEntity'
        expect(response_body['errors'].first['detail']).to eq 'Assign a droplet before starting this app.'
        expect(response).to have_http_status :unprocessable_entity
      end
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        put :start, params: { guid: 'meowmeowmeow' }, as: :json

        response_body = parsed_body
        expect(response_body['errors'].first['title']).to eq 'CF-ResourceNotFound'
        expect(response).to have_http_status :not_found
      end
    end

    context 'when the user has an invalid app' do
      before do
        allow(VCAP::CloudController::AppStart).to receive(:start).
          and_raise(VCAP::CloudController::AppStart::InvalidApp.new)
      end

      it 'returns an UnprocessableEntity error' do
        put :start, params: { guid: app_model.guid }, as: :json

        response_body = parsed_body
        expect(response_body['errors'].first['title']).to eq 'CF-UnprocessableEntity'
        expect(response).to have_http_status :unprocessable_entity
      end
    end

    context 'when requesting docker lifecycle and diego_docker feature flag is disabled' do
      let(:app_model) { VCAP::CloudController::AppModel.make(:docker, droplet_guid: droplet.guid) }
      let(:droplet) { VCAP::CloudController::DropletModel.make(:docker, state: VCAP::CloudController::DropletModel::STAGED_STATE) }

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: false, error_message: nil)
      end

      context 'admin' do
        before do
          set_current_user_as_admin(user:)
        end

        it 'raises 403' do
          put :start, params: { guid: app_model.guid }, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_docker')
        end
      end

      context 'non-admin' do
        it 'raises 403' do
          put :start, params: { guid: app_model.guid }, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_docker')
        end
      end
    end
  end

  describe '#stop' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid, desired_state: 'STARTED') }
    let(:droplet) { VCAP::CloudController::DropletModel.make(state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space:)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 200 and the app' do
      put :stop, params: { guid: app_model.guid }, as: :json

      response_body = parsed_body

      expect(response).to have_http_status :ok
      expect(response_body['guid']).to eq(app_model.guid)
      expect(response_body['state']).to eq('STOPPED')
    end

    context 'permissions' do
      context 'when the user does not have the write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          put :stop, params: { guid: app_model.guid }, as: :json

          expect(response).to have_http_status :forbidden
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space:)
        end

        it 'returns a 404 ResourceNotFound error' do
          put :stop, params: { guid: app_model.guid }, as: :json

          expect(response).to have_http_status :not_found
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but cannot write to the app' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space:)
        end

        it 'raises ApiError NotAuthorized' do
          put :stop, params: { guid: app_model.guid }, as: :json

          expect(response).to have_http_status :forbidden
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end

    context 'when the app does not exist' do
      it 'raises an API 404 error' do
        put :stop, params: { guid: 'thing' }, as: :json

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the user has an invalid app' do
      before do
        allow(VCAP::CloudController::AppStop).
          to receive(:stop).and_raise(VCAP::CloudController::AppStop::InvalidApp.new)
      end

      it 'returns an UnprocessableEntity error' do
        put :stop, params: { guid: app_model.guid }, as: :json

        expect(response).to have_http_status :unprocessable_entity
        expect(response.body).to include 'UnprocessableEntity'
      end
    end
  end

  describe '#restart' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid, desired_state: 'STARTED') }
    let(:droplet) { VCAP::CloudController::DropletModel.make(state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    context 'permissions' do
      describe 'authorization' do
        role_to_expected_http_response = {
          'admin' => 200,
          'admin_read_only' => 403,
          'global_auditor' => 403,
          'space_developer' => 200,
          'space_manager' => 403,
          'space_auditor' => 403,
          'org_manager' => 403,
          'org_auditor' => 404,
          'org_billing_manager' => 404
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(role:, org:, space:, user:)

              post :restart, params: { guid: app_model.guid }, as: :json

              expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
            end
          end
        end
      end
    end

    context 'when the user has permission' do
      before do
        set_current_user(user)
        allow_user_read_access_for(user, spaces: [space])
        allow_user_write_access(user, space:)
      end

      it 'returns a 200 and the app' do
        post :restart, params: { guid: app_model.guid }, as: :json

        response_body = parsed_body

        expect(response).to have_http_status :ok
        expect(response_body['guid']).to eq(app_model.guid)
        expect(response_body['state']).to eq('STARTED')
      end

      it 'restarts the app' do
        allow(VCAP::CloudController::AppRestart).to receive(:restart).and_call_original
        post :restart, params: { guid: app_model.guid }, as: :json

        response_body = parsed_body

        expect(response).to have_http_status :ok
        expect(response_body['guid']).to eq(app_model.guid)
        expect(response_body['state']).to eq('STARTED')
        expect(VCAP::CloudController::AppRestart).to have_received(:restart).with(app: app_model, config: anything, user_audit_info: anything)
      end

      context 'when the app does not exist' do
        it 'raises an API 404 error' do
          post :restart, params: { guid: 'thing' }, as: :json

          expect(response).to have_http_status :not_found
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the app does not have a droplet' do
        before do
          droplet.destroy
        end

        it 'raises an API 422 error' do
          post :restart, params: { guid: app_model.guid }, as: :json

          response_body = parsed_body
          expect(response_body['errors'].first['title']).to eq 'CF-UnprocessableEntity'
          expect(response_body['errors'].first['detail']).to eq 'Assign a droplet before starting this app.'
          expect(response).to have_http_status :unprocessable_entity
        end
      end

      context 'when requesting docker lifecycle' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:docker, droplet_guid: droplet.guid) }
        let(:droplet) { VCAP::CloudController::DropletModel.make(:docker, state: VCAP::CloudController::DropletModel::STAGED_STATE) }

        context 'and diego_docker feature flag is enabled' do
          before do
            VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
          end

          it 'returns 200' do
            post :restart, params: { guid: app_model.guid }, as: :json

            expect(response).to have_http_status(:ok)
          end
        end

        context 'and diego_docker feature flag is disabled' do
          before do
            app_model.buildpack_lifecycle_data = nil
            VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: false, error_message: nil)
          end

          context 'admin' do
            before do
              set_current_user_as_admin(user:)
            end

            it 'raises 403' do
              post :restart, params: { guid: app_model.guid }, as: :json

              expect(response).to have_http_status(:forbidden)
              expect(response.body).to include('FeatureDisabled')
              expect(response.body).to include('diego_docker')
            end
          end

          context 'non-admin' do
            it 'raises 403' do
              post :restart, params: { guid: app_model.guid }, as: :json

              expect(response).to have_http_status(:forbidden)
              expect(response.body).to include('FeatureDisabled')
              expect(response.body).to include('diego_docker')
            end
          end
        end
      end

      context 'when restarting the app fails with an AppRestart::Error' do
        before do
          allow(VCAP::CloudController::AppRestart).to receive(:restart).
            and_raise(VCAP::CloudController::AppRestart::Error.new('Ahhh!'))
        end

        it 'returns an UnprocessableEntity error' do
          post :restart, params: { guid: app_model.guid }, as: :json

          response_body = parsed_body
          expect(response).to have_http_status :unprocessable_entity
          expect(response_body['errors'].first['title']).to eq 'CF-UnprocessableEntity'
          expect(response_body['errors'].first['detail']).to eq 'Ahhh!'
        end
      end

      context 'when restarting the app fails with a CannotCommunicateWithDiegoError' do
        before do
          allow(VCAP::CloudController::AppRestart).to receive(:restart).
            and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError.new('Oh no!'))
        end

        it 'returns an CannotCommunicateWithDiegoError error' do
          post :restart, params: { guid: app_model.guid }, as: :json

          response_body = parsed_body
          expect(response).to have_http_status :service_unavailable
          expect(response_body['errors'].first['title']).to eq 'CF-RunnerUnavailable'
          expect(response_body['errors'].first['detail']).
            to eq 'Runner is unavailable: Unable to communicate with Diego'
        end
      end
    end
  end

  describe '#builds' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }
    let!(:build1) { VCAP::CloudController::BuildModel.make(app_guid: app_model.guid, guid: 'build-1') }
    let!(:build2) { VCAP::CloudController::BuildModel.make(app_guid: app_model.guid, guid: 'build-2') }

    before do
      set_current_user_as_admin(user:)
    end

    context 'when the given app does not exist' do
      it 'returns a validation error' do
        get :builds, params: { guid: 'no-such-app' }

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when given an invalid request' do
      it 'returns a validation error' do
        get :builds, params: { guid: app_model.guid, 'no-such-param': 42 }

        expect(response).to have_http_status :bad_request
        expect(response.body).to include 'BadQueryParameter'
        expect(response.body).to include 'no-such-param'
      end
    end

    it 'returns a 200 and lists the app\'s builds' do
      get :builds, params: { guid: app_model.guid }

      expect(response).to have_http_status(:ok)
      expect(parsed_body['resources'].size).to eq(2)
      expect(parsed_body['resources'].pluck('guid')).to contain_exactly(build1.guid, build2.guid)
    end

    it 'paginates with query parameters' do
      get :builds, params: { guid: app_model.guid, states: 'STAGED', per_page: 1 }

      expect(response.status).to eq(200), response.body
      expect(parsed_body['resources'].size).to eq(1)
      expect(parsed_body['resources'][0]['guid']).to eq(build1.guid)

      expect(parsed_body['pagination']['previous']).to be_nil
      expect(parsed_body['pagination']['next']['href']).to start_with("#{link_prefix}/v3/apps/#{app_model.guid}/builds")
      expect(parsed_body['pagination']['next']['href']).to match(/per_page=1/)
      expect(parsed_body['pagination']['next']['href']).to match(/page=2/)
      expect(parsed_body['pagination']['next']['href']).to match(/states=#{VCAP::CloudController::BuildModel::STAGED_STATE}/)
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) { READ_ONLY_PERMS }
      let(:api_call) { -> { get :builds, params: { guid: app_model.guid } } }
    end
  end

  describe '#show_env' do
    let(:app_model) { VCAP::CloudController::AppModel.make(environment_variables: { meep: 'moop', beep: 'boop' }) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user, email: 'mona@example.com')
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space:)
      allow_user_secret_access(user, space:)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and the environment variables' do
      get :show_env, params: { guid: app_model.guid }

      expect(response).to have_http_status :ok
      expect(parsed_body['environment_variables']).to eq(app_model.environment_variables)
    end

    it 'records an audit event' do
      expect do
        get :show_env, params: { guid: app_model.guid }
      end.to change(VCAP::CloudController::Event, :count).by(1)

      event = VCAP::CloudController::Event.find(type: 'audit.app.environment.show')
      expect(event).not_to be_nil
      expect(event.actor).to eq(user.guid)
      expect(event.actor_type).to eq('user')
      expect(event.actor_name).to eq('mona@example.com')
      expect(event.actee).to eq(app_model.guid)
      expect(event.actee_type).to eq('app')
      expect(event.actee_name).to eq(app_model.name)
      expect(event.timestamp).to be
      expect(event.space_guid).to eq(app_model.space_guid)
      expect(event.organization_guid).to eq(app_model.space.organization.guid)
      expect(event.metadata).to eq({})
    end

    context 'permissions' do
      context 'when the user does not have read permissions' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])
        end

        it 'returns a 403' do
          get :show_env, params: { guid: app_model.guid }

          expect(response).to have_http_status :forbidden
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          disallow_user_read_access(user, space:)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :show_env, params: { guid: app_model.guid }

          expect(response).to have_http_status :not_found
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when user can see secrets' do
        before do
          allow_user_secret_access(user, space:)
        end

        it 'succeeds' do
          get :show_env, params: { guid: app_model.guid }
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when user can not see secrets' do
        before do
          disallow_user_secret_access(user, space:)
        end

        it 'raises ApiError NotAuthorized' do
          get :show_env, params: { guid: app_model.guid }

          expect(response).to have_http_status :forbidden
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the space_developer_env_var_visibility feature flag is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'space_developer_env_var_visibility', enabled: false, error_message: nil)
        end

        it 'raises 403 for non-admins' do
          get :show_env, params: { guid: app_model.guid }

          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('space_developer_env_var_visibility')
        end

        it 'succeeds for admins' do
          set_current_user_as_admin(user:)
          get :show_env, params: { guid: app_model.guid }

          expect(response).to have_http_status(:ok)
        end

        it 'succeeds for admins_read_only' do
          set_current_user_as_admin_read_only(user:)
          get :show_env, params: { guid: app_model.guid }

          expect(response).to have_http_status(:ok)
        end

        context 'when user can not see secrets' do
          before do
            disallow_user_secret_access(user, space:)
          end

          it 'raises ApiError NotAuthorized as opposed to FeatureDisabled' do
            get :show_env, params: { guid: app_model.guid }

            expect(response).to have_http_status :forbidden
            expect(response.body).to include 'NotAuthorized'
          end
        end
      end

      context 'when the env_var_visibility feature flag is disabled' do
        before do
          allow_user_secret_access(user, space:)
          VCAP::CloudController::FeatureFlag.make(name: 'env_var_visibility', enabled: false, error_message: nil)
        end

        it 'raises 403 for all users' do
          set_current_user_as_admin(user:)
          get :show_env, params: { guid: app_model.guid }

          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('Feature Disabled: env_var_visibility')
        end
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show_env, params: { guid: 'beep-boop' }

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end
  end

  describe '#show_environment_variables' do
    let(:app_model) { VCAP::CloudController::AppModel.make(environment_variables: { meep: 'moop', beep: 'boop' }) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    let(:expected_success_response) do
      {
        'var' => {
          'meep' => 'moop',
          'beep' => 'boop'
        },
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" }
        }
      }
    end

    before do
      set_current_user(user, scopes: ['cloud_controller.read'])
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'space_developer' => 200,
        'org_manager' => 403,
        'org_user' => 404,
        'space_manager' => 403,
        'space_auditor' => 403,
        'org_auditor' => 404,
        'org_billing_manager' => 404,
        'admin' => 200,
        'admin_read_only' => 200
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user, scopes: ['cloud_controller.read'])

            get :show_environment_variables, params: { guid: app_model.guid }, as: :json

            expect(response.status).to eq expected_return_value
            expect(parsed_body).to eq(expected_success_response) if expected_return_value == 200
          end
        end
      end

      context 'when the space_developer_env_var_visibility feature flag is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'space_developer_env_var_visibility', enabled: false, error_message: nil)
        end

        role_to_expected_http_response.merge({ 'space_developer' => 403 }).each do |role, expected_return_value|
          context "as an #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(role:, org:, space:, user:)

              get :show_environment_variables, params: { guid: app_model.guid }, as: :json

              expect(response.status).to eq expected_return_value
              if role == 'space_developer'
                expect(response.body).to include('FeatureDisabled')
                expect(response.body).to include('space_developer_env_var_visibility')
              end
            end
          end
        end
      end

      context 'when the env_var_visibility feature flag is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'env_var_visibility', enabled: false, error_message: nil)
        end

        it 'raises 403 for all users' do
          set_current_user_as_admin(user:)
          get :show_environment_variables, params: { guid: app_model.guid }, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(response.body).to include('Feature Disabled: env_var_visibility')
        end
      end
    end

    context 'when the user does not have read scope' do
      let(:user) { VCAP::CloudController::User.make }

      before do
        org.add_user(user)
        space.add_developer(user)
        set_current_user(user, scopes: [])
      end

      it 'returns a 403' do
        get :show_environment_variables, params: { guid: app_model.guid }, as: :json

        expect(response).to have_http_status :forbidden
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :show_environment_variables, params: { guid: 'beep-boop' }, as: :json

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the app does not have environment variables' do
      let(:app_model) { VCAP::CloudController::AppModel.make }

      it 'returns 200 and the set of links' do
        set_current_user_as_admin(user:)
        get :show_environment_variables, params: { guid: app_model.guid }, as: :json

        expect(response).to have_http_status(:ok)
        expect(parsed_body).to eq({
                                    'links' => expected_success_response['links'],
                                    'var' => {}
                                  })
      end
    end

    it 'records an audit event' do
      set_current_user_as_admin(user: user, email: 'mona@example.com')

      expect do
        get :show_environment_variables, params: { guid: app_model.guid }, as: :json
      end.to change(VCAP::CloudController::Event, :count).by(1)

      event = VCAP::CloudController::Event.find(type: 'audit.app.environment_variables.show')
      expect(event).not_to be_nil
      expect(event.actor).to eq(user.guid)
      expect(event.actor_type).to eq('user')
      expect(event.actor_name).to eq('mona@example.com')
      expect(event.actee).to eq(app_model.guid)
      expect(event.actee_type).to eq('app')
      expect(event.actee_name).to eq(app_model.name)
      expect(event.timestamp).to be
      expect(event.space_guid).to eq(app_model.space_guid)
      expect(event.organization_guid).to eq(app_model.space.organization.guid)
      expect(event.metadata).to eq({})
    end
  end

  describe '#update_environment_variables' do
    let(:app_model) { VCAP::CloudController::AppModel.make(environment_variables: { override: 'value-to-override', preserve: 'value-to-keep' }) }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    let(:expected_success_response) do
      {
        'var' => {
          'override' => 'new-value',
          'preserve' => 'value-to-keep',
          'new-key' => 'another-new-value'
        },
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" }
        }
      }
    end

    let(:request_body) do
      {
        'var' => {
          'override' => 'new-value',
          'new-key' => 'another-new-value'
        }
      }
    end

    before do
      set_current_user(user)
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'space_developer' => 200,
        'org_manager' => 403,
        'org_user' => 404,
        'space_manager' => 403,
        'space_auditor' => 403,
        'org_auditor' => 404,
        'org_billing_manager' => 404,
        'admin' => 200,
        'admin_read_only' => 403
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role:, org:, space:, user:)

            patch :update_environment_variables, params: { guid: app_model.guid }.merge(request_body), as: :json

            expect(response.status).to eq(expected_return_value)
            if expected_return_value == 200
              expect(parsed_body).to eq(expected_success_response)

              app_model.reload
              expect(app_model.environment_variables).to eq({
                                                              'override' => 'new-value',
                                                              'preserve' => 'value-to-keep',
                                                              'new-key' => 'another-new-value'
                                                            })
            end
          end
        end
      end
    end

    context 'when the given app does not exist' do
      before do
        set_current_user_as_admin(user:)
      end

      it 'returns a validation error' do
        patch :update_environment_variables, params: { guid: 'fake-guid' }.merge(request_body), as: :json

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when given an invalid request' do
      let(:request_body) do
        {
          'var' => {
            'PORT' => 8080
          }
        }
      end

      before do
        set_current_user_as_admin(user:)
      end

      it 'returns a validation error' do
        patch :update_environment_variables, params: { guid: app_model.guid }.merge(request_body), as: :json

        expect(response).to have_http_status :unprocessable_entity
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'PORT'
      end
    end

    context 'when given a non-string value' do
      let(:request_body) do
        {
          'var' => {
            'hashes_not_allowed' => { 'var' => 'value' }
          }
        }
      end

      before do
        set_current_user_as_admin(user:)
      end

      it 'returns a validation error' do
        patch :update_environment_variables, params: { guid: app_model.guid }.merge(request_body), as: :json

        expect(response).to have_http_status :unprocessable_entity
        expect(response.body).to include "Non-string value in environment variable for key 'hashes_not_allowed'"
      end
    end
  end

  describe '#assign_current_droplet' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:droplet) { VCAP::CloudController::DropletModel.make(process_types: { 'web' => 'start app' }, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:request_body) { { data: { guid: droplet.guid } } }
    let(:droplet_link) { { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" } }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      app_model.add_droplet(droplet)
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space:)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns 200 and the droplet guid' do
      put :assign_current_droplet, params: { guid: app_model.guid }.merge(request_body), as: :json

      response_body = parsed_body

      expect(response).to have_http_status(:ok)
      expect(response_body['data']['guid']).to eq(droplet.guid)
      expect(response_body['links']['related']).to eq(droplet_link)
    end

    context 'the user does not provide the data key' do
      let(:request_body) { {} }

      it 'returns a 422' do
        put :assign_current_droplet, params: { guid: app_model.guid }.merge(request_body), as: :json

        expect(response).to have_http_status :unprocessable_entity
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Unable to assign current droplet. Ensure the droplet exists and belongs to this app.'
      end
    end

    context 'the user does not provide any droplet guid element' do
      let(:request_body) { { data: nil } }

      it 'returns a 422' do
        put :assign_current_droplet, params: { guid: app_model.guid }.merge(request_body), as: :json

        expect(response).to have_http_status :unprocessable_entity
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Current droplet cannot be removed. Replace it with a preferred droplet.'
      end
    end

    context 'and the droplet is not associated with the application' do
      let(:unassociated_droplet) { VCAP::CloudController::DropletModel.make }
      let(:request_body) { { data: { guid: unassociated_droplet.guid } } }

      it 'returns a 422' do
        put :assign_current_droplet, params: { guid: app_model.guid }.merge(request_body), as: :json

        expect(response).to have_http_status :unprocessable_entity
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Unable to assign current droplet. Ensure the droplet exists and belongs to this app.'
      end
    end

    context 'and the droplet does not exist' do
      let(:request_body) { { data: { guid: 'pitter-patter-zim-zoom' } } }

      it 'returns a 422' do
        put :assign_current_droplet, params: { guid: app_model.guid }.merge(request_body), as: :json

        expect(response).to have_http_status :unprocessable_entity
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Unable to assign current droplet. Ensure the droplet exists and belongs to this app.'
      end
    end

    context 'when the application does not exist' do
      it 'returns a 404 ResourceNotFound' do
        put :assign_current_droplet, params: { guid: 'i-do-not-exist' }.merge(request_body), as: :json

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the app is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::AppAssignDroplet).to receive(:assign).
          and_raise(VCAP::CloudController::AppAssignDroplet::InvalidApp.new('app is broked'))
      end

      it 'returns an UnprocessableEntity error' do
        put :assign_current_droplet, params: { guid: app_model.guid }.merge(request_body), as: :json

        expect(response).to have_http_status :unprocessable_entity
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when the app has a Deployment in flight' do
      context 'when the deployment is deploying' do
        before do
          VCAP::CloudController::DeploymentModel.make(app: app_model, state: 'DEPLOYING')
        end

        it 'returns an UnprocessableEntity error' do
          put :assign_current_droplet, params: { guid: app_model.guid }.merge(request_body), as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include 'UnprocessableEntity'
          expect(response.body).to include 'Unable to assign current droplet while the app has a deployment in progress. Wait for the deployment to complete or cancel it.'
        end
      end
    end

    context 'permissions' do
      context 'when the user does not have write permissions' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          put :assign_current_droplet, params: { guid: app_model.guid }.merge(request_body), as: :json

          expect(response).to have_http_status :forbidden
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user can not read the application' do
        before do
          disallow_user_read_access(user, space:)
        end

        it 'returns a 404 ResourceNotFound' do
          put :assign_current_droplet, params: { guid: app_model.guid }.merge(request_body), as: :json

          expect(response).to have_http_status :not_found
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user can read but not update the application' do
        before do
          allow_user_read_access_for(user, spaces: [space])
          disallow_user_write_access(user, space:)
        end

        it 'returns a 403 NotAuthorized' do
          put :assign_current_droplet, params: { guid: app_model.guid }.merge(request_body), as: :json

          expect(response).to have_http_status :forbidden
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end

  describe '#current_droplet' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(process_types: { 'web' => 'start app' }, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:droplet_link) { { 'href' => "/v3/apps/#{app_model.guid}/droplets/current" } }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      app_model.add_droplet(droplet)
      set_current_user(user)
    end

    context 'when the application does not exist' do
      it 'returns a 404 ResourceNotFound' do
        get :current_droplet, params: { guid: 'i do not exist' }

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the current droplet is not set' do
      let(:app_model) { VCAP::CloudController::AppModel.make }

      it 'returns a 404 Not Found' do
        get :current_droplet, params: { guid: app_model.guid }

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('ResourceNotFound')
      end
    end
  end

  describe '#current_droplet_relationship' do
    let(:app_model) { VCAP::CloudController::AppModel.make(droplet_guid: droplet.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(process_types: { 'web' => 'start app' }, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:droplet_link) { { 'href' => "/v3/apps/#{app_model.guid}/droplets/current" } }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:user) { VCAP::CloudController::User.make }

    before do
      app_model.add_droplet(droplet)
      set_current_user(user)
    end

    context 'when the application does not exist' do
      it 'returns a 404 ResourceNotFound' do
        get :current_droplet_relationship, params: { guid: 'i do not exist' }

        expect(response).to have_http_status :not_found
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the current droplet is not set' do
      let(:app_model) { VCAP::CloudController::AppModel.make }

      it 'returns a 404 Not Found' do
        get :current_droplet_relationship, params: { guid: app_model.guid }

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('ResourceNotFound')
      end
    end
  end

  describe 'DeleteAppErrorTranslatorJob' do
    let(:error_translator) { AppsV3Controller::DeleteAppErrorTranslatorJob.new(job) }
    let(:job) {}

    context 'when the error is a SubResourceError' do
      it 'translates it to CompoundError with underlying API errors' do
        translated_error = error_translator.translate_error(VCAP::CloudController::AppDelete::SubResourceError.new([
          StandardError.new('oops-1'),
          StandardError.new('oops-2')
        ]))

        expect(translated_error).to be_a(CloudController::Errors::CompoundError)
        expect(translated_error.underlying_errors).to contain_exactly(CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'oops-1'),
                                                                      CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'oops-2'))
      end
    end

    context 'when the error is not a SubResourceError' do
      it 'justs return it' do
        err = StandardError.new('oops')

        translated_error = error_translator.translate_error(err)

        expect(translated_error).to eq(err)
      end
    end
  end
end
