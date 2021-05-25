require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Route Destinations Request' do
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }

  before do
    TestConfig.override(kubernetes: {})
  end

  context 'buildpack table test' do
    let(:app_model) { VCAP::CloudController::AppModel.make(:docker, space: space) }
    let!(:process_model) { VCAP::CloudController::ProcessModel.make(:docker, app: app_model, type: 'web') }
    let(:route1) { VCAP::CloudController::Route.make(space: space) }
    let(:route2) { VCAP::CloudController::Route.make(space: space) }

    [
      # case,  dst1 specified port,   dst2 specified port,   dst1 actual port,   dst2 actual port,   exposed ports,
      [0,      nil,                   nil,                   8080,               8080,               [8080]],
      [1,      nil,                   2222,                  8080,               2222,               [8080, 2222]],
      [2,      1111,                  nil,                   1111,               8080,               [1111, 8080]],
      [3,      1111,                  2222,                  1111,               2222,               [1111, 2222]],
      [4,      nil,                   8080,                  8080,               8080,               [8080]],
    ].each do |sample, dst1_specified_port, dst2_specified_port, expected_dst1_port, expected_dst2_port, expected_exposed_ports|
      it "case #{sample}" do
        params1 = {
          app: { guid: app_model.guid },
        }
        params1[:port] = dst1_specified_port if dst1_specified_port

        post "/v3/routes/#{route1.guid}/destinations", { destinations: [params1] }.to_json, admin_header
        expect(last_response.status).to eq(200)

        params2 = {
          app: { guid: app_model.guid },
        }
        params2[:port] = dst2_specified_port if dst2_specified_port

        post "/v3/routes/#{route2.guid}/destinations", { destinations: [params2] }.to_json, admin_header
        expect(last_response.status).to eq(200)

        get "/v3/routes/#{route1.guid}/destinations", nil, admin_header
        expect(last_response.status).to eq(200)

        actual_dst1_port = parsed_response['destinations'][0]['port']
        expect(actual_dst1_port).to eq(expected_dst1_port)

        get "/v3/routes/#{route2.guid}/destinations", nil, admin_header
        expect(last_response.status).to eq(200)

        actual_dst2_port = parsed_response['destinations'][0]['port']
        expect(actual_dst2_port).to eq(expected_dst2_port)

        get "/v2/apps/#{app_model.guid}", nil, admin_header
        expect(last_response.status).to eq(200)
        expect(parsed_response['entity']['ports']).not_to be_nil
        expect(parsed_response['entity']['ports']).to contain_exactly(*expected_exposed_ports)
      end
    end
  end

  context 'docker table test' do
    let(:app_model) { VCAP::CloudController::AppModel.make(:docker, space: space) }
    let!(:process_model) { VCAP::CloudController::ProcessModel.make(:docker, app: app_model, type: 'web') }
    let(:route1) { VCAP::CloudController::Route.make(space: space) }
    let(:route2) { VCAP::CloudController::Route.make(space: space) }

    [
      # case,  dst1 specified port,   dst2 specified port,   docker ports,   dst1 actual port,   dst2 actual port,   exposed ports,
      [0,      nil,                   nil,                   [],             8080,               8080,               [8080]],
      [1,      nil,                   nil,                   [3333],         3333,               3333,               [3333]],
      [2,      nil,                   2222,                  [],             8080,               2222,               [8080, 2222]],
      [3,      nil,                   2222,                  [3333],         3333,               2222,               [3333, 2222]],
      [4,      1111,                  nil,                   [],             1111,               8080,               [1111, 8080]],
      [5,      1111,                  nil,                   [3333],         1111,               3333,               [1111, 3333]],
      [6,      1111,                  2222,                  [],             1111,               2222,               [1111, 2222]],
      [7,      1111,                  2222,                  [3333],         1111,               2222,               [1111, 2222]],
      [8,      nil,                   8080,                  [],             8080,               8080,               [8080]],
    ].each do |sample, dst1_specified_port, dst2_specified_port, docker_ports, expected_dst1_port, expected_dst2_port, expected_exposed_ports|
      it "case #{sample}" do
        params1 = {
          app: { guid: app_model.guid },
        }
        params1[:port] = dst1_specified_port if dst1_specified_port

        post "/v3/routes/#{route1.guid}/destinations", { destinations: [params1] }.to_json, admin_header
        expect(last_response.status).to eq(200)

        params2 = {
          app: { guid: app_model.guid },
        }
        params2[:port] = dst2_specified_port if dst2_specified_port

        post "/v3/routes/#{route2.guid}/destinations", { destinations: [params2] }.to_json, admin_header
        expect(last_response.status).to eq(200)

        droplet = VCAP::CloudController::DropletModel.make(
          :docker,
          app: app_model,
          execution_metadata: {
            ports: docker_ports.map { |dp| { Port: dp, Protocol: 'tcp' } }
          }.to_json,
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
        )
        app_model.update(droplet: droplet)

        get "/v3/routes/#{route1.guid}/destinations", nil, admin_header
        expect(last_response.status).to eq(200)

        actual_dst1_port = parsed_response['destinations'][0]['port']
        expect(actual_dst1_port).to eq(expected_dst1_port)

        get "/v3/routes/#{route2.guid}/destinations", nil, admin_header
        expect(last_response.status).to eq(200)

        actual_dst2_port = parsed_response['destinations'][0]['port']
        expect(actual_dst2_port).to eq(expected_dst2_port)

        get "/v2/apps/#{app_model.guid}", nil, admin_header
        expect(last_response.status).to eq(200)
        expect(parsed_response['entity']['ports']).not_to be_nil
        expect(parsed_response['entity']['ports']).to contain_exactly(*expected_exposed_ports)
      end
    end
  end

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
            weight: nil,
            port: 8080
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

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ['space_application_supporter']
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

    context 'filters' do
      let(:app_model2) { VCAP::CloudController::AppModel.make(space: space) }
      let!(:destination2) { VCAP::CloudController::RouteMappingModel.make(app: app_model2, route: route, process_type: 'web') }

      context 'when filtering on app_guids' do
        it 'returns only the destinations for the requested app_guids' do
          get "/v3/routes/#{route.guid}/destinations?app_guids=#{app_model.guid}", nil, admin_header
          expect(parsed_response).to match_json_response(response_json)
        end
      end

      context 'when filtering on destination guids' do
        it 'returns only the destinations for the requested destination guids' do
          get "/v3/routes/#{route.guid}/destinations?guids=#{destination.guid}", nil, admin_header
          expect(parsed_response).to match_json_response(response_json)
        end
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
              weight: nil,
              port: 8080
            },
            {
              guid: UUID_REGEX,
              app: {
                guid: app_model.guid,
                process: {
                  type: 'web'
                }
              },
              weight: nil,
              port: 8080
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
        h['space_application_supporter'] = { code: 200, response_object: response_json }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ['space_application_supporter'] do
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
              route_mapping_guid: new_destination['guid'],
              destination_guid: new_destination['guid'],
              process_type: 'web',
              weight: nil
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
              weight: nil,
              port: 8080
            },
            {
              guid: UUID_REGEX,
              app: {
                guid: app_model.guid,
                process: {
                  type: 'worker'
                }
              },
              weight: nil,
              port: 8080
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
        h['space_application_supporter'] = { code: 200, response_object: response_json }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ['space_application_supporter']

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

    context 'when two different destinations have the same port' do
      let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app_model, ports: [9000], type: 'web') }
      let!(:existing_destination) do
        VCAP::CloudController::RouteMappingModel.make(
          app: app_model,
          route: route,
          app_port: 9000
        )
      end

      let(:params) do
        {
          destinations: [
            {
              app: {
                guid: app_model.guid,
              },
              weight: 80,
              port: 8080
            },
            {
              app: {
                guid: app_model.guid,
              },
              weight: 20,
              port: 9000
            }
          ]
        }
      end

      it 'successfully updates the process ports' do
        patch "/v3/routes/#{route.guid}/destinations", params.to_json, admin_header
        expect(last_response.status).to eq 200
      end
    end

    context 'when two destinations match a currently existing destination' do
      let!(:existing_destination_1) do
        VCAP::CloudController::RouteMappingModel.make(
          app: app_model,
          route: route,
          app_port: 9000,
          weight: 1
        )
      end

      let!(:existing_destination_2) do
        VCAP::CloudController::RouteMappingModel.make(
          app: app_model,
          route: route,
          app_port: 8080,
          weight: 99
        )
      end

      let(:params) do
        {
          destinations: [
            {
              app: {
                guid: app_model.guid,
              },
              weight: 1,
              port: 9000
            },
            {
              app: {
                guid: app_model.guid,
              },
              weight: 1,
              port: 9000
            },
            {
              app: {
                guid: app_model.guid,
              },
              weight: 98,
              port: 8080
            },
          ]
        }
      end

      it 'returns a useful error message' do
        patch "/v3/routes/#{route.guid}/destinations", params.to_json, admin_header
        expect(last_response.status).to eq 422
        expect(parsed_response['errors'][0]['detail']).to eq 'Destinations cannot contain duplicate entries'
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
        app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT,
        weight: nil
      )
    end

    let!(:destination_to_delete) do
      VCAP::CloudController::RouteMappingModel.make(
        app: app_model,
        route: route,
        process_type: 'worker',
        app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT,
        weight: nil
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
        h['space_application_supporter'] = { code: 204 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS + ['space_application_supporter'] do
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
              route_mapping_guid: destination_to_delete.guid,
              destination_guid: destination_to_delete.guid,
              process_type: destination_to_delete.process_type,
              weight: nil
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
