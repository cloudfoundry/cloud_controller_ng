require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::RouteMappingsController do
    describe 'Route Mappings' do
      describe 'Query Parameters' do
        it { expect(described_class).to be_queryable_by(:app_guid) }
        it { expect(described_class).to be_queryable_by(:route_guid) }
      end

      describe 'Permissions' do
        include_context 'permissions'

        before do
          @app_a = AppFactory.make(space: @space_a)
          @app_b = AppFactory.make(space: @space_b)
          @route_a = Route.make(space: @space_a)
          @route_b = Route.make(space: @space_b)
          @obj_a = RouteMapping.make(app_guid: @app_a.guid, route_guid: @route_a.guid)
          @obj_b = RouteMapping.make(app_guid: @app_b.guid, route_guid: @route_b.guid)
        end

        describe 'Org Level Permissions' do
          describe 'OrgManager' do
            let(:member_a) { @org_a_manager }
            let(:member_b) { @org_b_manager }

            include_examples 'permission enumeration', 'OrgManager',
                             name: 'route_mapping',
                             path: '/v2/route_mappings',
                             enumerate: 1
          end

          describe 'OrgUser' do
            let(:member_a) { @org_a_member }
            let(:member_b) { @org_b_member }

            include_examples 'permission enumeration', 'OrgUser',
                             name: 'route_mapping',
                             path: '/v2/route_mappings',
                             enumerate: 0
          end

          describe 'BillingManager' do
            let(:member_a) { @org_a_billing_manager }
            let(:member_b) { @org_b_billing_manager }

            include_examples 'permission enumeration', 'BillingManager',
                             name: 'route_mapping',
                             path: '/v2/route_mappings',
                             enumerate: 0
          end

          describe 'Auditor' do
            let(:member_a) { @org_a_auditor }
            let(:member_b) { @org_b_auditor }

            include_examples 'permission enumeration', 'Auditor',
                             name: 'route_mapping',
                             path: '/v2/route_mappings',
                             enumerate: 0
          end
        end

        describe 'App Space Level Permissions' do
          describe 'SpaceManager' do
            let(:member_a) { @space_a_manager }
            let(:member_b) { @space_b_manager }

            include_examples 'permission enumeration', 'SpaceManager',
                             name: 'route_mapping',
                             path: '/v2/route_mappings',
                             enumerate: 1
          end

          describe 'Developer' do
            let(:member_a) { @space_a_developer }
            let(:member_b) { @space_b_developer }

            include_examples 'permission enumeration', 'Developer',
                             name: 'route_mapping',
                             path: '/v2/route_mappings',
                             enumerate: 1
          end

          describe 'SpaceAuditor' do
            let(:member_a) { @space_a_auditor }
            let(:member_b) { @space_b_auditor }

            include_examples 'permission enumeration', 'SpaceAuditor',
                             name: 'route_mapping',
                             path: '/v2/route_mappings',
                             enumerate: 1
          end
        end
      end

      describe 'POST /v2/route_mappings' do
        let(:route) { Route.make }
        let(:app_obj) { AppFactory.make(space: space) }
        let(:space) { route.space }
        let(:developer) { make_developer_for_space(space) }

        before do
          set_current_user(developer)
        end

        context 'when the app does not exist' do
          let(:body) do
            {
              app_guid: 'app_obj_guid',
              route_guid: route.guid
            }.to_json
          end

          it 'returns with a NotFound error' do
            post '/v2/route_mappings', body

            expect(last_response).to have_status_code(404)
            expect(decoded_response['description']).to include('The app could not be found')
          end
        end

        context 'when the route does not exist' do
          let(:body) do
            {
              app_guid: app_obj.guid,
              route_guid: 'route_guid'
            }.to_json
          end

          it 'returns with a NotFound error' do
            post '/v2/route_mappings', body

            expect(last_response).to have_status_code(404)
            expect(decoded_response['description']).to include('The route could not be found')
          end
        end

        context 'when the app is a diego app' do
          let(:app_obj) { AppFactory.make(space: space, diego: true, ports: [8080, 9090]) }
          let(:body) do
            {
              app_guid: app_obj.guid,
              route_guid: route.guid
            }.to_json
          end

          context 'and no app port is specified' do
            it 'uses the first port in the list of app ports' do
              post '/v2/route_mappings', body

              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to eq(8080)

              warning = CGI.unescape(last_response.headers['X-Cf-Warnings'])
              expect(warning).to include('Route has been mapped to app port 8080.')
            end

            context 'when another mapping with the same port already exists' do
              it 'does not create another route mapping' do
                post '/v2/route_mappings', body
                expect(last_response).to have_status_code(201)
                expect(decoded_response['entity']['app_port']).to eq(8080)

                post '/v2/route_mappings', body
                expect(last_response).to have_status_code(400)
                expect(decoded_response['code']).to eq(210006)
              end
            end
          end

          context 'and there is another app already bound to the specified route' do
            let(:route_2) { Route.make(space: space) }
            let(:body_2) do
              {
                app_guid: app_obj.guid,
                route_guid: route_2.guid
              }.to_json
            end

            before do
              post '/v2/route_mappings', body_2
              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to eq(8080)
            end

            it 'still makes a route mapping from the app to the route' do
              post '/v2/route_mappings', body
              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to eq(8080)
            end
          end

          context 'and the app is bound to another route' do
            let(:app_obj_2) { AppFactory.make(space: space, diego: true, ports: [9090]) }
            let(:body) do
              {
                app_guid: app_obj.guid,
                route_guid: route.guid,
                app_port: 9090
              }.to_json
            end
            let(:body_2) do
              {
                app_guid: app_obj_2.guid,
                route_guid: route.guid,
                app_port: 9090
              }.to_json
            end

            before do
              post '/v2/route_mappings', body_2
              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to eq(9090)
            end

            it 'still makes a route mapping from the app to the route' do
              post '/v2/route_mappings', body
              expect(last_response).to have_status_code(201)
            end

            it 'makes the route mapping even if the port number is the same' do
              post '/v2/route_mappings', body
              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to eq(9090)
            end
          end

          context 'and an app port not bound to the application is specified' do
            let(:body) do
              {
                app_guid: app_obj.guid,
                route_guid: route.guid,
                app_port: 7777
              }.to_json
            end

            it 'returns a 400' do
              post '/v2/route_mappings', body

              expect(last_response).to have_status_code(400)
              expect(decoded_response['description']).to include('Routes can only be mapped to ports already enabled for the application')
            end
          end

          context 'and a valid app port is specified' do
            let(:body) do
              {
                app_guid: app_obj.guid,
                route_guid: route.guid,
                app_port: 9090
              }.to_json
            end

            it 'uses the app port specified' do
              post '/v2/route_mappings', body

              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to eq(9090)

              expect(last_response.headers['X-Cf-Warnings']).to be_nil
            end

            context 'when the same route mapping with the same port is specified' do
              it 'does not create another route mapping' do
                post '/v2/route_mappings', body
                expect(last_response).to have_status_code(201)
                expect(decoded_response['entity']['app_port']).to eq(9090)

                post '/v2/route_mappings', body
                expect(last_response).to have_status_code(400)
                expect(decoded_response['code']).to eq(210006)
                expect(decoded_response['description']).to include('port 9090')
              end
            end

            context 'when the same route mapping with the different port is specified' do
              it 'creates another route mapping' do
                post '/v2/route_mappings', body
                expect(last_response).to have_status_code(201)
                expect(decoded_response['entity']['app_port']).to eq(9090)

                body = {
                    app_guid: app_obj.guid,
                    route_guid: route.guid,
                    app_port: 8080
                  }.to_json
                post '/v2/route_mappings', body
                expect(last_response).to have_status_code(201)
                expect(decoded_response['entity']['app_port']).to eq(8080)
              end
            end
          end

          context 'and developer of different space is specified' do
            let(:space1) { Space.make }
            let(:developer) { make_developer_for_space(space1) }
            let(:body) do
              {
                app_guid: app_obj.guid,
                route_guid: route.guid,
                app_port: 9090
              }.to_json
            end

            it 'gets unauhtorized error' do
              post '/v2/route_mappings', body

              expect(last_response).to have_status_code(403)
            end
          end
        end

        context 'when the app is a DEA app' do
          let(:app_obj) { AppFactory.make(space: space, diego: false) }

          context 'and app port is not specified' do
            let(:body) do
              {
                app_guid: app_obj.guid,
                route_guid: route.guid
              }.to_json
            end

            it 'returns a 201' do
              post '/v2/route_mappings', body

              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to be_nil
            end
          end

          context 'and app port is specified' do
            let(:body) do
              {
                app_guid: app_obj.guid,
                route_guid: route.guid,
                app_port: 8080
              }.to_json
            end

            it 'returns a 400' do
              post '/v2/route_mappings', body

              expect(last_response).to have_status_code(400)
              expect(decoded_response['description']).to include('App ports are supported for Diego apps only')
            end
          end

          context 'when same route mapping is specified' do
            let(:body) do
              {
                  app_guid: app_obj.guid,
                  route_guid: route.guid
              }.to_json
            end

            it 'does not create another route mapping' do
              post '/v2/route_mappings', body
              expect(last_response).to have_status_code(201)

              post '/v2/route_mappings', body
              expect(last_response).to have_status_code(400)
              expect(decoded_response['code']).to eq(210006)
              expect(decoded_response['description']).to_not include('port')
            end
          end
        end

        context 'when the Routing API is not enabled' do
          let(:space_quota) { SpaceQuotaDefinition.make(organization: space.organization) }
          let(:tcp_domain) { SharedDomain.make(name: 'tcp.com', router_group_guid: 'guid_1') }
          let(:tcp_route) { Route.make(port: 9090, host: '', space: space, domain: tcp_domain) }
          let(:app_obj) { AppFactory.make(space: space, ports: [9090], diego: true) }
          let(:space_developer) { make_developer_for_space(space) }
          let(:body) do
            {
                app_guid: app_obj.guid,
                route_guid: tcp_route.guid
            }.to_json
          end

          before do
            space.space_quota_definition = space_quota
            allow_any_instance_of(RouteValidator).to receive(:validate)
            TestConfig.override(routing_api: nil)
          end

          it 'returns 403' do
            post '/v2/route_mappings', body
            expect(last_response).to have_status_code(403)
            expect(decoded_response['description']).to include('Support for TCP routing is disabled')
          end
        end
      end

      describe 'PUT /v2/route_mappings/:guid' do
        let(:route) { Route.make }
        let(:app_obj) { AppFactory.make(space: space, ports: [8080, 9090], diego: true) }
        let(:space) { route.space }
        let(:route_mapping) { RouteMapping.make(app_guid: app_obj.guid, route_guid: route.guid) }
        let(:space_developer) { make_developer_for_space(space) }

        before do
          set_current_user(space_developer)
        end

        context 'as SpaceDeveloper' do
          it 'returns 201' do
            put "/v2/route_mappings/#{route_mapping.guid}", '{ "app_port": 9090 }'
            expect(last_response).to have_status_code(201)
          end
        end

        context 'as SpaceDeveloper for another space' do
          it 'returns 403' do
            set_current_user(User.make)
            put "/v2/route_mappings/#{route_mapping.guid}", '{ "app_port": 9090 }'
            expect(last_response).to have_status_code(403)
          end
        end

        context 'when updating app_guid and route_guid' do
          let(:body) do
            {
                app_port: 9090,
                app_guid: '123',
                route_guid: '456'
            }.to_json
          end

          it 'does not update non-updatable fields' do
            put "/v2/route_mappings/#{route_mapping.guid}", body
            expect(last_response).to have_status_code(201)
            expect(decoded_response['entity']['app_port']).to eq 9090
            expect(decoded_response['entity']['app_guid']).to eq app_obj.guid
            expect(decoded_response['entity']['route_guid']).to eq route.guid
          end
        end
      end

      describe 'DELETE /v2/route_mappings/:guid' do
        let(:route) { Route.make }
        let(:app_obj) { AppFactory.make(space: space) }
        let(:space) { route.space }
        let(:developer) { make_developer_for_space(space) }
        let(:route_mapping) { RouteMapping.make(app_guid: app_obj.guid, route_guid: route.guid) }

        before do
          set_current_user(developer)
        end

        it 'deletes the route mapping' do
          delete "/v2/route_mappings/#{route_mapping.guid}"

          expect(last_response).to have_status_code(204)
        end

        it 'does not delete the associated app and route' do
          delete "/v2/route_mappings/#{route_mapping.guid}"

          expect(last_response).to have_status_code(204)
          expect(route).to exist
          expect(app_obj).to exist
        end

        context 'when the route mapping does not exist' do
          it 'raises an informative error' do
            delete '/v2/route_mappings/nonexistent-guid'

            expect(last_response).to have_status_code(404)
            expect(last_response.body).to include 'RouteMappingNotFound'
          end
        end
      end
    end
  end
end
