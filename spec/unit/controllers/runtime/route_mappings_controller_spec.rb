require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::RouteMappingsController do
    describe 'Route Mappings' do
      describe 'Permissions' do
        it 'does permission things'
      end

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

        # context 'when the app is a diego app' do
        #   let(:app_obj) { AppFactory.make(space: space, diego: true, ports: [8080]) }
        #
        #   context 'and no app port is specified' do
        #     let(:body) do
        #       {
        #         app_guid: app_obj.guid,
        #         route_guid: route.guid
        #       }.to_json
        #     end
        #
        #     it 'uses the first port in the list of app ports' do
        #       post '/v2/route_mappings', body, headers_for(developer)
        #
        #       expect(last_response).to have_status_code(201)
        #       expect(decoded_response['entity']['app_port']).to eq(8080)
        #     end
        #   end
        #
        #   context 'and an app port is specified' do
        #     let(:body) do
        #       {
        #         app_guid: app_obj.guid,
        #         route_guid: route.guid,
        #         app_port: 9090
        #       }.to_json
        #     end
        #
        #     it 'uses the app port specified' do
        #       post '/v2/route_mappings', body, headers_for(developer)
        #
        #       expect(last_response).to have_status_code(201)
        #       expect(decoded_response['entity']['app_port']).to eq(9090)
        #     end
        #   end
        # end
        #
        # context 'when the app is a DEA app' do
        #   let(:app_obj) { AppFactory.make(space: space, diego: false) }
        #   context 'and app port is not specified' do
        #     let(:body) do
        #       {
        #         app_guid: app_obj.guid,
        #         route_guid: route.guid
        #       }.to_json
        #     end
        #     it 'returns a 201' do
        #       post '/v2/route_mappings', body, headers_for(developer)
        #
        #       expect(last_response).to have_status_code(201)
        #       expect(decoded_response['entity']['app_port']).to be_nil
        #     end
        #   end
        # end
      end
    end
  end
end