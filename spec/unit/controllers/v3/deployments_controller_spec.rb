require 'rails_helper'
require 'permissions_spec_helper'
require 'messages/deployment_create_message'

RSpec.describe DeploymentsController, type: :controller do
  let(:user) { VCAP::CloudController::User.make }
  let(:app) { VCAP::CloudController::AppModel.make(desired_state: VCAP::CloudController::ProcessModel::STARTED) }
  let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app) }
  let(:droplet) { VCAP::CloudController::DropletModel.make(app: app, process_types: { 'web' => 'spider' }) }
  let(:app_guid) { app.guid }
  let(:space) { app.space }
  let(:org) { space.organization }

  describe '#create' do
    before do
      TestConfig.override(temporary_disable_deployments: false)
      app.update(droplet: droplet)
    end

    let(:request_body) do
      {
        relationships: {
          app: {
            data: {
              guid: app_guid
            }
          }
        },
      }
    end

    describe 'for a valid user' do
      before do
        set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
      end

      it 'returns a 201' do
        post :create, params: request_body, as: :json

        expect(response.status).to eq(201)
      end

      context 'when a droplet is not provided' do
        it 'creates a deployment using the app\'s current droplet' do
          expect(VCAP::CloudController::DeploymentCreate).
            to receive(:create).
            with(
              app: app,
              user_audit_info: instance_of(VCAP::CloudController::UserAuditInfo),
              message: instance_of(VCAP::CloudController::DeploymentCreateMessage),
              ).and_call_original

          post :create, params: request_body, as: :json
        end

        context 'the app does not have a current droplet' do
          let(:app_without_droplet) {
            VCAP::CloudController::AppModel.make(
              desired_state: VCAP::CloudController::ProcessModel::STARTED,
              space: space
            )
          }

          let(:request_body) do
            {
             relationships: {
                app: {
                  data: {
                    guid: app_without_droplet.guid
                  }
                }
              },
            }
          end

          it 'returns a 422' do
            post :create, params: request_body, as: :json

            expect(response.status).to eq 422
            expect(response.body).to include('UnprocessableEntity')
            expect(response.body).to include('Invalid droplet. Please specify a droplet in the request or set a current droplet for the app.')
          end
        end
      end

      context 'when a droplet is provided' do
        let(:other_droplet) { VCAP::CloudController::DropletModel.make(app: app, process_types: { web: 'start-me-up' }) }
        let(:request_body) do
          {
            droplet: {
              guid: other_droplet.guid
            },
            relationships: {
              app: {
                data: {
                  guid: app_guid
                }
              }
            },
          }
        end

        context 'when revisions are disabled' do
          before do
            app.update(revisions_enabled: false)
          end

          it 'creates a deployment' do
            expect(VCAP::CloudController::DeploymentCreate).
              to receive(:create).
              with(
                app: app,
                user_audit_info: instance_of(VCAP::CloudController::UserAuditInfo),
                message: instance_of(VCAP::CloudController::DeploymentCreateMessage),
                ).and_call_original

            expect {
              post :create, params: request_body, as: :json
            }.not_to change { VCAP::CloudController::RevisionModel.count }
          end
        end

        it 'creates a revision' do
          expect(VCAP::CloudController::DeploymentCreate).
            to receive(:create).
            with(
              app: app,
              user_audit_info: instance_of(VCAP::CloudController::UserAuditInfo),
              message: instance_of(VCAP::CloudController::DeploymentCreateMessage),
              ).and_call_original

          expect {
            post :create, params: request_body, as: :json
          }.to change { VCAP::CloudController::RevisionModel.count }.by(1)
        end

        it 'sets the app droplet to the provided droplet' do
          post :create, params: request_body, as: :json

          expect(app.reload.droplet).to eq(other_droplet)
        end

        context 'the droplet is not associated with the application' do
          let(:unassociated_droplet) { VCAP::CloudController::DropletModel.make }
          let(:request_body) do
            {
              droplet: {
                guid: unassociated_droplet.guid
              },
              relationships: {
                app: {
                  data: {
                    guid: app_guid
                  }
                }
              },
            }
          end

          it 'returns a 422' do
            post :create, params: request_body, as: :json

            expect(response.status).to eq 422
            expect(response.body).to include('UnprocessableEntity')
            expect(response.body).to include('Unable to assign current droplet. Ensure the droplet exists and belongs to this app.')
          end
        end

        context 'the droplet does not exist' do
          let(:request_body) do
            {
              droplet: {
                guid: 'pitter-patter-zim-zoom'
              },
              relationships: {
                app: {
                  data: {
                    guid: app_guid
                  }
                }
              },
            }
          end

          it 'returns a 422' do
            post :create, params: request_body, as: :json

            expect(response.status).to eq 422
            expect(response.body).to include('UnprocessableEntity')
            expect(response.body).to include('Unable to assign current droplet. Ensure the droplet exists and belongs to this app.')
          end
        end
      end

      context 'when the app does not exist' do
        let(:app_guid) { 'does-not-exist' }

        it 'returns 422 with an error message' do
          post :create, params: request_body, as: :json
          expect(response.status).to eq 422
          expect(response.body).to include('Unable to use app. Ensure that the app exists and you have access to it.')
        end
      end

      context 'when a revision is provided' do
        let(:newer_droplet) { VCAP::CloudController::DropletModel.make(app: app, process_types: { 'web' => 'rackup' }) }
        let!(:earlier_revision) do
          VCAP::CloudController::RevisionModel.make(app: app, droplet_guid: droplet.guid, created_at: 5.days.ago, version: 2, description: 'earlier revision')
        end
        let!(:later_revision) do
          VCAP::CloudController::RevisionModel.make(app: app, droplet_guid: newer_droplet.guid, version: 3, description: 'later revision')
        end

        let(:request_body) do
          {
            revision: {
              guid: earlier_revision.guid
            },
            relationships: {
              app: {
                data: {
                  guid: app_guid
                }
              }
            },
          }
        end

        it 'uses the droplet from the revision to create a new revision' do
          expect(VCAP::CloudController::DeploymentCreate).
            to receive(:create).
            with(
              app: app,
              user_audit_info: instance_of(VCAP::CloudController::UserAuditInfo),
              message: instance_of(VCAP::CloudController::DeploymentCreateMessage),
              ).and_call_original

          expect {
            post :create, params: request_body, as: :json
          }.to change { VCAP::CloudController::RevisionModel.count }.by(1)
          expect(VCAP::CloudController::RevisionModel.last.droplet_guid).to eq(droplet.guid)
        end

        context 'when the provided revision specifies start commands' do
          let!(:earlier_revision) do
            VCAP::CloudController::RevisionModel.make(:custom_web_command,
              app: app,
              droplet_guid: newer_droplet.guid, # same droplet as currently associated revision
              created_at: 5.days.ago,
              version: 2,
              description: 'reassigned earlier_revision',
            )
          end

          it 'uses the process commands from the revision to create a new revision' do
            expect(VCAP::CloudController::DeploymentCreate).
              to receive(:create).and_call_original
            expect {
              post :create, params: request_body, as: :json
            }.to change { VCAP::CloudController::RevisionModel.count }.by(1)
            expect(VCAP::CloudController::RevisionModel.last.commands_by_process_type).to eq({ 'web' => 'custom_web_command' })
          end
        end

        it 'returns a 422 and an error if the revision does not exist' do
          earlier_revision.destroy
          post :create, params: request_body, as: :json

          expect(response.status).to eq 422
          expect(response.body).to include('UnprocessableEntity')
          expect(response.body).to include('The revision does not exist')
        end

        it 'returns a 422 and an error if droplet in the revision does not exist' do
          droplet.destroy
          post :create, params: request_body, as: :json

          expect(response.status).to eq 422
          expect(response.body).to include('UnprocessableEntity')
          expect(response.body).to include('Unable to deploy this revision, the droplet for this revision no longer exists.')
        end

        it 'returns a 422 and an error if revisions are not enabled' do
          app.update(revisions_enabled: false)

          post :create, params: request_body, as: :json
          expect(response.status).to eq 422
          expect(response.body).to include('Cannot create deployment from a revision for an app without revisions enabled')
        end
      end

      context 'when both a revision and a droplet are provided' do
        let!(:revision) { VCAP::CloudController::RevisionModel.make(app: app) }
        let(:request_body) do
          {
            droplet: {
              guid: droplet.guid
            },
            revision: {
              guid: revision.guid
            },
            relationships: {
              app: {
                data: {
                  guid: app_guid
                }
              }
            },
          }
        end

        it 'returns 422 with an error message' do
          post :create, params: request_body, as: :json
          expect(response.status).to eq 422
          expect(response.body).to include("Cannot set both fields 'droplet' and 'revision'")
        end
      end

      context 'when metadata is provided' do
        let(:metadata) {
          {
            'labels' => {
              'seriouseats.com/potato' => 'mashed',
            },
            'annotations' => {
              'potato' => 'idaho',
            },
          }
        }

        let(:request_body) do
          {
            relationships: {
              app: {
                data: {
                  guid: app_guid
                }
              }
            },
            metadata: metadata,
          }
        end

        it 'sets some metadata' do
          post :create, params: request_body, as: :json

          expect(response.status).to eq(201)
          expect(parsed_body['metadata']).to eq(metadata)
        end
      end
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) do
        {
          'admin' => 201,
          'admin_read_only' => 422,
          'global_auditor' => 422,
          'space_developer' => 201,
          'space_manager' => 422,
          'space_auditor' => 422,
          'org_manager' => 422,
          'org_auditor' => 422,
          'org_billing_manager' => 422,
        }
      end
      let(:api_call) { lambda { post :create, params: request_body, as: :json } }
    end

    context 'when the user does not have permission' do
      before do
        set_current_user(user, scopes: %w(cloud_controller.write))
      end

      it 'returns 422 with an error message' do
        post :create, params: request_body, as: :json
        expect(response.status).to eq 422
        expect(response.body).to include('Unable to use app. Ensure that the app exists and you have access to it.')
      end
    end

    it 'returns 401 for Unauthenticated requests' do
      post :create, params: request_body, as: :json
      expect(response.status).to eq(401)
    end

    context 'when temporary_disable_deployments is true' do
      before do
        TestConfig.override(temporary_disable_deployments: true)
        set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
      end

      it 'returns a 403' do
        post :create, params: request_body, as: :json

        expect(response.status).to eq(403)
        expect(response.body).to include("Deployments cannot be created due to manifest property 'temporary_disable_deployments'")
      end

      it 'does not create a deployment' do
        expect(VCAP::CloudController::DeploymentCreate).not_to receive(:create)

        post :create, params: request_body, as: :json
      end
    end
  end

  describe '#show' do
    let(:deployment) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app, droplet: droplet) }

    describe 'for a valid user' do
      before do
        set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
      end

      it 'returns a 200 on show existing deployment' do
        get :show, params: { guid: deployment.guid }, as: :json

        expect(response.status).to eq(200)
        expect(parsed_body['guid']).to eq(deployment.guid)
      end

      it 'returns a 404 on bogus deployment' do
        get :show, params: { guid: 'not a deployment' }, as: :json

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end

      context 'when the current droplet changes on the app' do
        let(:new_droplet) { VCAP::CloudController::DropletModel.make }

        it 'shows the droplet guid for the droplet the deployment was created with' do
          app.update(droplet: new_droplet)

          get :show, params: { guid: deployment.guid }, as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['guid']).to eq(deployment.guid)
          expect(parsed_body['relationships']['app']['data']['guid']).to eq(app.guid)
          expect(parsed_body['droplet']['guid']).to eq(droplet.guid)
        end
      end
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) do
        {
          'admin' => 200,
          'admin_read_only' => 200,
          'global_auditor' => 200,
          'space_developer' => 200,
          'space_manager' => 200,
          'space_auditor' => 200,
          'org_manager' => 200,
          'org_auditor' => 404,
          'org_billing_manager' => 404,
        }
      end
      let(:api_call) { lambda { get :show, params: { guid: deployment.guid }, as: :json } }
    end

    it 'returns 401 for Unauthenticated requests' do
      get :show, params: { guid: deployment.guid }, as: :json
      expect(response.status).to eq(401)
    end
  end

  describe '#index' do
    let!(:deployment) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app) }
    let!(:another_deployment) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app) }

    context 'permissions' do
      describe 'authorization' do
        role_to_expected_http_response = {
          'admin' => 200,
          'admin_read_only' => 200,
          'global_auditor' => 200,
          'space_developer' => 200,
          'space_manager' => 200,
          'space_auditor' => 200,
          'org_manager' => 200,
          'org_auditor' => 200,
          'org_billing_manager' => 200,
        }.freeze

        has_no_space_access = {
          'org_auditor' => true,
          'org_billing_manager' => true,
        }

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(role: role, org: org, space: space, user: user)

              get :index
              expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
              resources = parsed_body['resources']
              if has_no_space_access[role]
                expect(resources.size).to eq(0), "role #{role}: expected 0, got: #{resources.size}"
              else
                expect(resources.size).to eq(2), "role #{role}: expected 2, got: #{resources.size}"
                expect(resources.map { |r| r['guid'] }).to match_array([deployment.guid, another_deployment.guid])
              end
            end
          end
        end
      end

      context 'when the user does not have the "cloud_controller.read" scope' do
        before do
          set_current_user(user, scopes: [])
        end

        it 'returns a 403 Not Authorized error' do
          get :index

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end

    describe 'request validity and pagination' do
      before do
        set_current_user_as_admin(user: user)
      end

      context 'query params' do
        context 'invalid param format' do
          let(:params) { { 'order_by' => '^%' } }

          it 'returns 400' do
            get :index, params: params

            expect(response.status).to eq(400)
            expect(response.body).to include('BadQueryParameter')
            expect(response.body).to include("Order by can only be: 'created_at', 'updated_at'")
          end
        end

        context 'unknown query param' do
          let(:params) { { 'bad_param' => 'foo' } }

          it 'returns 400' do
            get :index, params: params

            expect(response.status).to eq(400)
            expect(response.body).to include('BadQueryParameter')
            expect(response.body).to include('Unknown query parameter(s)')
            expect(response.body).to include('bad_param')
          end
        end

        context 'invalid pagination' do
          let(:params) { { 'per_page' => 9999999999999999 } }

          it 'returns 400' do
            get :index, params: params

            expect(response.status).to eq(400)
            expect(response.body).to include('BadQueryParameter')
            expect(response.body).to include('Per page must be between')
          end
        end

        context 'query params in pagination links' do
          let(:params) { { 'per_page' => 1 } }

          it 'adds requested params to the links' do
            get :index, params: params

            expect(response.status).to eq(200)
            expect(parsed_body['pagination']['next']['href']).to start_with("#{link_prefix}/v3/deployments")
            expect(parsed_body['pagination']['next']['href']).to match(/per_page=1/)
            expect(parsed_body['pagination']['next']['href']).to match(/page=2/)
          end
        end

        context 'when querying by states' do
          let(:states_list) { 'DEPLOYED,CANCELED' }
          let(:params) { { states: states_list } }
          let!(:deployed_deployment) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYED', app: app) }
          let!(:canceled_deployment) { VCAP::CloudController::DeploymentModel.make(state: 'CANCELED', app: app) }

          it 'gets only the requested deployments' do
            get :index, params: params

            expect(response.status).to eq(200)
            expect(parsed_body['resources'].map { |r| r['guid'] }).to match_array([deployed_deployment.guid, canceled_deployment.guid])
          end

          it 'echo the params in the pagination links' do
            get :index, params: params.merge({ per_page: 1 })

            expect(response.status).to eq(200)
            expect(parsed_body['pagination']['next']['href']).to match(/states=#{CGI.escape(states_list)}/)
          end
        end
      end
    end
  end

  describe '#cancel' do
    let!(:deployment) do
      VCAP::CloudController::DeploymentModel.make(
        state: 'DEPLOYING',
        app: app,
        previous_droplet: VCAP::CloudController::DropletModel.make(app: app, process_types: { 'web' => 'www' })
      )
    end

    before do
      set_current_user_as_admin(user: user)
    end

    it 'returns 404 not found when the deployment does not exist' do
      post :cancel, params: { guid: 'non-existant-giud' }

      expect(response.status).to eq(404)
    end

    it 'returns a 200 and cancels the deployment' do
      expect(VCAP::CloudController::DeploymentCancel).to receive(:cancel).with(deployment: deployment, user_audit_info: anything)

      post :cancel, params: { guid: deployment.guid }

      expect(response.status).to eq(200)
      expect(response.body).to be_empty
    end

    describe 'when canceling the deployment raises an error' do
      it 'returns a 422' do
        error = VCAP::CloudController::DeploymentCancel::Error.new 'something went awry'
        allow(VCAP::CloudController::DeploymentCancel).to receive(:cancel).and_raise(error)

        post :cancel, params: { guid: deployment.guid }

        expect(response.status).to eq(422)
        expect(response.body).to match /awry/
      end
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) do
        {
          'admin' => 200,
          'admin_read_only' => 404,
          'global_auditor' => 404,
          'space_developer' => 200,
          'space_manager' => 404,
          'space_auditor' => 404,
          'org_manager' => 404,
          'org_auditor' => 404,
          'org_billing_manager' => 404,
        }
      end
      let(:api_call) { lambda { post :cancel, params: { guid: deployment.guid } } }
    end
  end

  describe '#update' do
    let(:deployment) { VCAP::CloudController::DeploymentModel.make(app: app) }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
    end

    context 'when there is an invalid message validation failure' do
      let(:request_body) do
        {
          metadata: {
            labels: 'value'
          }
        }
      end
      it 'displays an informative error' do
        patch :update, params: { guid: deployment.guid }.merge(request_body), as: :json
        expect(response.status).to eq(422)
        expect(response).to have_error_message("labels' is not an object")
      end
    end

    context 'permissions' do
      context 'when the user cannot read the deployment due to roles' do
        before do
          disallow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          patch :update, params: { guid: deployment.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but cannot write to the space' do
        before do
          disallow_user_write_access(user, space: space)
        end

        it 'returns 403 NotAuthorized' do
          patch :update, params: { guid: deployment.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end

    context 'metadata' do
      context 'with labels' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                key: 'value'
              }
            }
          }
        end

        it 'updates' do
          patch :update, params: { guid: deployment.guid }.merge(request_body), as: :json
          expect(response.status).to eq(200)
          expect(parsed_body['guid']).to eq(deployment.guid)
          expect(parsed_body['metadata']['labels']['key']).to eq('value')
        end
      end
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
          patch :update, params: { guid: deployment.guid }.merge(request_body), as: :json

          expect(response.status).to eq 422
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
              },
            }
          }
        end

        it 'returns an UnprocessableEntity error' do
          patch :update, params: { guid: deployment.guid }.merge(request_body), as: :json

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
          expect(response).to have_error_message(/annotation [\w\s]+ error/)
        end
      end

      context 'when the metadata is valid' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                release: 'stable'
              },
              annotations: {
                this: 'is valid'
              },
            }
          }
        end

        it 'Returns a 200 and the deployment with metadata' do
          patch :update, params: { guid: deployment.guid }.merge(request_body), as: :json

          response_body = parsed_body
          response_metadata = response_body['metadata']

          expect(response.status).to eq 200
          expect(response_metadata['labels']['release']).to eq 'stable'
          expect(response_metadata['annotations']['this']).to eq 'is valid'
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
          patch :update, params: { guid: deployment.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response.body).to include 'Failed to add 2 annotations because it would exceed maximum of 1'
        end
      end

      context 'when there are too many labels' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                radish: 'daikon',
                potato: 'idaho'
              }
            }
          }
        end

        before do
          VCAP::CloudController::Config.config.set(:max_labels_per_resource, 1)
        end

        it 'responds with 422' do
          patch :update, params: { guid: deployment.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response.body).to include 'Failed to add 2 labels because it would exceed maximum of 1'
        end
      end
    end
  end
end
