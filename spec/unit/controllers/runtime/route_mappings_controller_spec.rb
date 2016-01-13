require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::RouteMappingsController do
    describe 'Route Mappings' do
      describe 'POST /v2/route_mappings' do
        let(:route) { Route.make }
        let(:app_obj) { AppFactory.make(space: space) }
        let(:space) { route.space }
        let(:developer) { make_developer_for_space(space) }

        context 'when the app does not exist' do
          let(:body) do
            {
              app_guid: 'app_obj_guid',
              route_guid: route.guid
            }.to_json
          end

          it 'returns with a NotFound error' do
            post '/v2/route_mappings', body, headers_for(developer)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include('Could not find VCAP::CloudController::App')
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
            post '/v2/route_mappings', body, headers_for(developer)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include('Could not find VCAP::CloudController::Route')
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
              post '/v2/route_mappings', body, headers_for(developer)

              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to eq(8080)
            end

            context 'when another mapping with the same port already exists' do
              it 'does not create another route mapping' do
                post '/v2/route_mappings', body, headers_for(developer)
                expect(last_response).to have_status_code(201)
                expect(decoded_response['entity']['app_port']).to eq(8080)

                post '/v2/route_mappings', body, headers_for(developer)
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
              post '/v2/route_mappings', body_2, headers_for(developer)
              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to eq(8080)
            end

            it 'still makes a route mapping from the app to the route' do
              post '/v2/route_mappings', body, headers_for(developer)
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
              post '/v2/route_mappings', body_2, headers_for(developer)
              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to eq(9090)
            end

            it 'still makes a route mapping from the app to the route' do
              post '/v2/route_mappings', body, headers_for(developer)
              expect(last_response).to have_status_code(201)
            end

            it 'makes the route mapping even if the port number is the same' do
              post '/v2/route_mappings', body, headers_for(developer)
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
              post '/v2/route_mappings', body, headers_for(developer)

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
              post '/v2/route_mappings', body, headers_for(developer)

              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['app_port']).to eq(9090)
            end

            context 'when the same route mapping with the same port is specified' do
              it 'does not create another route mapping' do
                post '/v2/route_mappings', body, headers_for(developer)
                expect(last_response).to have_status_code(201)
                expect(decoded_response['entity']['app_port']).to eq(9090)

                post '/v2/route_mappings', body, headers_for(developer)
                expect(last_response).to have_status_code(400)
                expect(decoded_response['code']).to eq(210006)
              end
            end

            context 'when the same route mapping with the different port is specified' do
              it 'creates another route mapping' do
                post '/v2/route_mappings', body, headers_for(developer)
                expect(last_response).to have_status_code(201)
                expect(decoded_response['entity']['app_port']).to eq(9090)

                body = {
                    app_guid: app_obj.guid,
                    route_guid: route.guid,
                    app_port: 8080
                  }.to_json
                post '/v2/route_mappings', body, headers_for(developer)
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
              post '/v2/route_mappings', body, headers_for(developer)

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
              post '/v2/route_mappings', body, headers_for(developer)

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
              post '/v2/route_mappings', body, headers_for(developer)

              expect(last_response).to have_status_code(400)
              expect(decoded_response['description']).to include('App ports are supported for Diego apps only')
            end
          end
        end
      end
    end
  end
end
