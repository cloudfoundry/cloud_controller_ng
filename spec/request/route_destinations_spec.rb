require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Route Destinations Request' do
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }

  describe 'GET /v3/routes/:guid/destinations' do
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
    let!(:destination) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route, process_type: 'web') }
    let(:api_call) { lambda { |user_headers| get "/v3/routes/#{route.guid}/destinations", nil, user_headers } }
    let(:response_json) do
      {
        destinations: [
          {
            guid: destination.guid,
            app: {
              guid: app_model.guid,
              process: {
                type: 'web'
              }
            },
            weight: nil
          }
        ],
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route.guid}\/destinations) },
          route: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route.guid}) }
        }
      }
    end

    context 'when the user is a member in the routes org' do
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: response_json
        )

        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the route does not exist' do
      let(:user_header) { headers_for(user) }

      it 'returns not found' do
        get '/v3/routes/does-not-exist/destinations', nil, user_header
        expect(last_response.status).to eq(404)
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get '/v3/routes/guid/destinations'
        expect(last_response.status).to eq(401)
      end
    end

    context 'when the user does not have the required scopes' do
      let(:user_header) { headers_for(user, scopes: []) }

      it 'returns a 403' do
        get "/v3/routes/#{route.guid}/destinations", nil, user_header
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'POST /v3/routes/:guid/destinations' do
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
    let(:user_header) { headers_for(user) }
    let!(:existing_destination) do
      VCAP::CloudController::RouteMappingModel.make(
        app: app_model,
        route: route,
        process_type: 'worker',
        app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT
      )
    end
    let(:params) do
      {
        destinations: [
          {
            app: {
              guid: app_model.guid,
              process: {
                type: 'web'
              }
            }
          },
          {
            app: {
              guid: app_model.guid,
              process: {
                type: existing_destination.process_type
              }
            }
          }
        ]
      }
    end

    context 'permissions' do
      let(:api_call) { lambda { |user_headers| post "/v3/routes/#{route.guid}/destinations", params.to_json, user_headers } }

      let(:response_json) do
        {
          destinations: [
            {
              guid: existing_destination.guid,
              app: {
                guid: app_model.guid,
                process: {
                  type: existing_destination.process_type
                }
              },
              weight: nil
            },
            {
              guid: UUID_REGEX,
              app: {
                guid: app_model.guid,
                process: {
                  type: 'web'
                }
              },
              weight: nil
            }
          ],
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route.guid}\/destinations) },
            route: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route.guid}) }
          }
        }
      end
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )

        h['admin'] = { code: 200, response_object: response_json }
        h['space_developer'] = { code: 200, response_object: response_json }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_event_hash) do
          new_destination = parsed_response['destinations'].detect { |dst| dst['guid'] != existing_destination.guid }

          {
            type: 'audit.app.map-route',
            actee: app_model.guid,
            actee_type: 'app',
            actee_name: app_model.name,
            space_guid: space.guid,
            organization_guid: org.guid,
            metadata: {
              route_guid: route.guid,
              app_port: 8080,
              destination_guid: new_destination['guid'],
              process_type: 'web'
            }.to_json,
          }
        end
      end

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          post "/v3/routes/#{route.guid}/destinations", params.to_json
          expect(last_response.status).to eq(401)
        end
      end

      context 'when the user does not have the required scopes' do
        let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

        it 'returns a 403' do
          post "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'when the user has permissions to the route' do
      before do
        set_current_user_as_role(user: user, role: 'space_developer', org: space.organization, space: space)
      end

      context 'when the route does not exist' do
        it 'returns not found' do
          post '/v3/routes/does-not-exist/destinations', params.to_json, user_header
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the org is suspended' do
        before do
          space.organization.status = 'suspended'
          space.organization.save
        end
        it 'returns a 403' do
          post "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
          expect(last_response.status).to eq(403)
        end
      end

      context 'when the app is invalid' do
        context 'when an app is outside the route space' do
          let(:app_model) { VCAP::CloudController::AppModel.make }
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: app_model.guid,
                    process: {
                      type: 'web'
                    }
                  }
                }
              ]
            }
          end

          before do
            set_current_user_as_role(user: user, role: 'space_developer', org: app_model.space.organization, space: app_model.space)
          end

          it 'returns a 403' do
            post "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
            expect(last_response.status).to eq(422)
          end
        end

        context 'when the app does not exist' do
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: 'whoops',
                    process: {
                      type: 'web'
                    }
                  }
                }
              ]
            }
          end

          it 'returns a 422' do
            post "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to match('App(s) with guid(s) "whoops" do not exist or you do not have access.')
          end
        end

        context 'when the process type is empty' do
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: app_model.guid,
                    process: {
                      type: ''
                    }
                  }
                }
              ]
            }
          end

          it 'returns a 422' do
            post "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to match('Destinations[0]: process must have the structure {"type": "process_type"}')
          end
        end

        context 'when multiple apps do *not* exist' do
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: 'whoops-1',
                    process: {
                      type: 'web'
                    }
                  }
                },
                {
                  app: {
                    guid: 'whoops-2',
                    process: {
                      type: 'web'
                    }
                  }
                }
              ]
            }
          end

          it 'returns a 422' do
            post "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to match('App(s) with guid(s) "whoops-1", "whoops-2" do not exist or you do not have access.')
          end
        end

        context 'when the user can not read the app' do
          let(:non_visible_space) { VCAP::CloudController::Space.make }
          let(:app_model) { VCAP::CloudController::AppModel.make(space: non_visible_space) }
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: app_model.guid,
                    process: {
                      type: 'web'
                    }
                  }
                }
              ]
            }
          end

          it 'returns a ' do
            post "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
            expect(last_response.status).to eq(422)
            expect(parsed_response['errors'][0]['detail']).to match("App(s) with guid(s) \"#{app_model.guid}\" do not exist or you do not have access.")
          end
        end
      end

      context 'when weights are involved' do
        before do
          VCAP::CloudController::RouteMappingModel.dataset.destroy
        end

        context 'when no destinations exist' do
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: app_model.guid,
                    process: {
                      type: 'web'
                    }
                  },
                  weight: 60
                },
                {
                  app: {
                    guid: app_model.guid,
                    process: {
                      type: 'worker'
                    }
                  },
                  weight: 40
                }
              ]
            }
          end

          it 'returns 422 with a helpful message' do
            post "/v3/routes/#{route.guid}/destinations", params.to_json, admin_header
            expect(last_response.status).to eq(422)
            expect(last_response).to have_error_message('Destinations[0]: weighted destinations can only be used when replacing all destinations.')
          end
        end
      end

      context 'when there is an existing weighted destination' do
        let!(:existing_destination) { VCAP::CloudController::RouteMappingModel.make(app: app_model, process_type: 'something', route: route, weight: 10) }

        it 'returns 422 with a helpful message' do
          post "/v3/routes/#{route.guid}/destinations", params.to_json, admin_header
          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message('Destinations cannot be inserted when there are weighted destinations already configured.')
        end
      end
    end
  end

  describe 'PATCH /v3/routes/:guid/destinations' do
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let(:user_header) { headers_for(user) }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
    let(:params) do
      {
        destinations: [
          {
            app: {
              guid: app_model.guid,
              process: {
                type: 'web'
              }
            }
          },
          {
            app: {
              guid: app_model.guid,
              process: {
                type: 'worker'
              }
            }
          }
        ]
      }
    end

    context 'when all destinations are for the same app' do
      let!(:existing_destination) do
        VCAP::CloudController::RouteMappingModel.make(
          app: app_model,
          route: route,
          process_type: 'assistant'
        )
      end

      it 'replaces all destinations on the route' do
        patch "/v3/routes/#{route.guid}/destinations", params.to_json, admin_header
        expect(last_response.status).to eq(200)
        expect(parsed_response['destinations'].map { |r| r['app']['process']['type'] }).to contain_exactly('web', 'worker')
        process_types = VCAP::CloudController::RouteMappingModel.where(app: app_model).all.collect(&:process_type)
        expect(process_types).to contain_exactly('web', 'worker')
      end
    end

    context 'when removing a destination app' do
      let(:app_model_1) { VCAP::CloudController::AppModel.make(space: space) }
      let(:app_model_2) { VCAP::CloudController::AppModel.make(space: space) }
      let!(:existing_destination_1) do
        VCAP::CloudController::RouteMappingModel.make(
          app: app_model_1,
          route: route,
          process_type: 'web',
          app_port: 8080,
        )
      end
      let!(:existing_destination_2) do
        VCAP::CloudController::RouteMappingModel.make(
          app: app_model_2,
          route: route,
          process_type: 'web',
          app_port: 8080,
        )
      end
      let(:params) do
        {
          destinations: [
            {
              app: {
                guid: app_model_1.guid,
                process: {
                  type: 'web'
                }
              }
            }
          ]
        }
      end

      it 'replaces all destinations on the route' do
        patch "/v3/routes/#{route.guid}/destinations", params.to_json, admin_header
        expect(last_response.status).to eq(200)
        expect(parsed_response['destinations'].map { |r| r['app']['guid'] }).to contain_exactly(app_model_1.guid)
      end
    end

    context 'when removing all destination apps' do
      let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
      let!(:existing_destination) do
        VCAP::CloudController::RouteMappingModel.make(
          app: app_model,
          route: route,
          process_type: 'web',
          app_port: 8080,
        )
      end
      let(:params) do
        {
          destinations: []
        }
      end

      it "removes all of the route's destinations" do
        expect(app_model.reload.routes).not_to be_empty
        patch "/v3/routes/#{route.guid}/destinations", params.to_json, admin_header
        expect(last_response.status).to eq(200)
        expect(parsed_response['destinations']).to be_empty
        expect(app_model.reload.routes).to be_empty
      end
    end

    context 'permissions' do
      let(:api_call) { lambda { |user_headers| patch "/v3/routes/#{route.guid}/destinations", params.to_json, user_headers } }
      let(:response_json) do
        {
          destinations: [
            {
              guid: UUID_REGEX,
              app: {
                guid: app_model.guid,
                process: {
                  type: 'web'
                }
              },
              weight: nil
            },
            {
              guid: UUID_REGEX,
              app: {
                guid: app_model.guid,
                process: {
                  type: 'worker'
                }
              },
              weight: nil
            }
          ],
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route.guid}\/destinations) },
            route: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route.guid}) }
          }
        }
      end
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )

        h['admin'] = { code: 200, response_object: response_json }
        h['space_developer'] = { code: 200, response_object: response_json }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          patch "/v3/routes/#{route.guid}/destinations", params.to_json
          expect(last_response.status).to eq(401)
        end
      end

      context 'when the user does not have the required scopes' do
        let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

        it 'returns a 403' do
          patch "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'when the user has permissions to the route' do
      before do
        set_current_user_as_role(user: user, role: 'space_developer', org: space.organization, space: space)
      end

      context 'when the route does not exist' do
        it 'returns not found' do
          patch '/v3/routes/does-not-exist/destinations', params.to_json, user_header
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the org is suspended' do
        before do
          space.organization.status = 'suspended'
          space.organization.save
        end
        it 'returns a 403' do
          patch "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
          expect(last_response.status).to eq(403)
        end
      end

      context 'when the app is invalid' do
        context 'when an app is outside the route space' do
          let(:app_model) { VCAP::CloudController::AppModel.make }
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: app_model.guid,
                    process: {
                      type: 'web'
                    }
                  }
                }
              ]
            }
          end

          before do
            set_current_user_as_role(user: user, role: 'space_developer', org: app_model.space.organization, space: app_model.space)
          end

          it 'returns a 403' do
            patch "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
            expect(last_response.status).to eq(422)
          end
        end

        context 'when the app does not exist' do
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: 'whoops',
                    process: {
                      type: 'web'
                    }
                  }
                }
              ]
            }
          end

          it 'returns a 422' do
            patch "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to match('App(s) with guid(s) "whoops" do not exist or you do not have access.')
          end
        end

        context 'when the process type is empty' do
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: app_model.guid,
                    process: {
                      type: ''
                    }
                  }
                }
              ]
            }
          end

          it 'returns a 422' do
            patch "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to match('Destinations[0]: process must have the structure {"type": "process_type"}')
          end
        end

        context 'when multiple apps do *not* exist' do
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: 'whoops-1',
                    process: {
                      type: 'web'
                    }
                  }
                },
                {
                  app: {
                    guid: 'whoops-2',
                    process: {
                      type: 'web'
                    }
                  }
                }
              ]
            }
          end

          it 'returns a 422' do
            patch "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to match('App(s) with guid(s) "whoops-1", "whoops-2" do not exist or you do not have access.')
          end
        end

        context 'when the user can not read the app' do
          let(:non_visible_space) { VCAP::CloudController::Space.make }
          let(:app_model) { VCAP::CloudController::AppModel.make(space: non_visible_space) }
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: app_model.guid,
                    process: {
                      type: 'web'
                    }
                  }
                }
              ]
            }
          end

          it 'returns a ' do
            patch "/v3/routes/#{route.guid}/destinations", params.to_json, user_header
            expect(last_response.status).to eq(422)
            expect(parsed_response['errors'][0]['detail']).to match("App(s) with guid(s) \"#{app_model.guid}\" do not exist or you do not have access.")
          end
        end
      end
    end

    describe 'weighted routing' do
      let(:params) do
        {
          destinations: [
            {
              app: {
                guid: app_model.guid,
                process: {
                  type: 'web'
                }
              },
              weight: 80
            },
            {
              app: {
                guid: app_model.guid,
                process: {
                  type: 'worker'
                }
              },
              weight: 20
            }
          ]
        }
      end

      it 'creates route destinations with weights' do
        patch "/v3/routes/#{route.guid}/destinations", params.to_json, admin_header
        expect(last_response.status).to eq(200)
        expect(parsed_response['destinations'].map { |r| r['weight'] }).to contain_exactly(80, 20)
        rm_hashes = route.reload.route_mappings.map do |rm|
          { process_type: rm.process_type, weight: rm.weight }
        end
        expect(rm_hashes).to contain_exactly(
          { process_type: 'web',    weight: 80 },
          { process_type: 'worker', weight: 20 }
        )
      end

      context 'when the destination weights do *not* add up to 100' do
        let(:params) do
          {
            destinations: [
              {
                app: { guid: app_model.guid },
                weight: 10
              }
            ]
          }
        end

        it 'returns 422 with a helpful message' do
          patch "/v3/routes/#{route.guid}/destinations", params.to_json, admin_header
          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message('Destinations must have weights that sum to 100.')
        end
      end

      context 'when there are both weighted and unweighted destinations' do
        let(:params) do
          {
            destinations: [
              {
                app: { guid: app_model.guid },
                weight: 10
              },
              {
                app: {
                  guid: app_model.guid,
                  process: {
                    type: 'worker'
                  }
                },
              }
            ]
          }
        end

        it 'returns 422 with a helpful message' do
          patch "/v3/routes/#{route.guid}/destinations", params.to_json, admin_header
          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message('Destinations cannot contain both weighted and unweighted destinations.')
        end
      end
    end
  end

  describe 'DELETE /v3/routes/:guid/destinations/:destination_guid' do
    let(:user_header) { headers_for(user) }
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }

    let!(:destination_to_preserve) do
      VCAP::CloudController::RouteMappingModel.make(
        app: app_model,
        route: route,
        process_type: 'web',
        app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT
      )
    end

    let!(:destination_to_delete) do
      VCAP::CloudController::RouteMappingModel.make(
        app: app_model,
        route: route,
        process_type: 'worker',
        app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT
      )
    end

    context 'permissions' do
      let(:api_call) { lambda { |user_headers| delete "/v3/routes/#{route.guid}/destinations/#{destination_to_delete.guid}", nil, user_headers } }

      let(:db_check) do
        lambda do
          get "/v3/routes/#{route.guid}/destinations", {}, admin_headers
          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['destinations'].length).to eq(1)
          expect(parsed_response['destinations'][0]['guid']).to eq(destination_to_preserve.guid)
        end
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )

        h['admin'] = { code: 204 }
        h['space_developer'] = { code: 204 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS do
        let(:expected_event_hash) do
          {
            type: 'audit.app.unmap-route',
            actee: app_model.guid,
            actee_type: 'app',
            actee_name: app_model.name,
            space_guid: space.guid,
            organization_guid: org.guid,
            metadata: {
              route_guid: route.guid,
              app_port: 8080,
              destination_guid: destination_to_delete.guid,
              process_type: destination_to_delete.process_type,
            }.to_json,
          }
        end
      end
    end

    context 'when the route does not exist' do
      it 'returns not found' do
        delete "/v3/routes/does-not-exist/destinations/#{destination_to_delete.guid}", nil, admin_header
        expect(last_response.status).to eq(404)
      end
    end

    context 'when the destination does not exist' do
      it 'returns 422 with a helpful message' do
        delete "/v3/routes/#{route.guid}/destinations/does-not-exist", nil, admin_header
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('Unable to unmap route from destination. Ensure the route has a destination with this guid.')
      end
    end

    context 'when there is an existing weighted destination' do
      let!(:existing_destination) { VCAP::CloudController::RouteMappingModel.make(app: app_model, process_type: 'something', route: route, weight: 10) }

      it 'returns 422 with a helpful message' do
        delete "/v3/routes/#{route.guid}/destinations/#{existing_destination.guid}", nil, admin_header
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('Weighted destinations cannot be deleted individually.')
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        delete "/v3/routes/#{route.guid}/destinations/#{destination_to_delete.guid}", nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end
  end
end
