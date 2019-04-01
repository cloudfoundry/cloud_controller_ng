require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'managed service instances spec' do
    include VCAP::CloudController::BrokerApiHelper

    context 'when updating a service instance' do
      let(:space) { Space.make }

      context 'when service plan is not public and not active' do
        let(:service) { Service.make(plan_updateable: true) }
        let(:service_plan) { ServicePlan.make(public: false, active: false, service: service) }
        let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }

        before do
          @broker_url = service_instance.service_broker.broker_url
          @service_instance_guid = service_instance.guid
        end

        context 'when the user is using admin headers' do
          let(:body) do
            {
              name: 'my-new-service-instance',
              tags: ['db'],
              parameters: { 'key' => 'value' }
            }
          end

          it 'should update the instance attributes' do
            update_service_instance(200, headers: admin_headers, body: body)

            expect(last_response).to have_status_code(201)
            expect(a_request(:patch, update_url(service_instance)).with { |req|
              request_body = JSON.parse(req.body)
              expect(request_body['parameters']).to eq(body[:parameters])
            }).to have_been_made

            parsed_response = JSON.parse(last_response.body)
            expect(parsed_response['entity']).to include(
              'name' => body[:name],
              'tags' => body[:tags]
            )
          end
        end

        context 'when the user is SpaceDeveloper' do
          let(:user) { User.make }

          before do
            space.organization.add_user(user)
            space.add_developer(user)
          end

          context 'when updating broker attributes' do
            let(:body) do
              {
                parameters: { 'foo' => 'bar' }
              }
            end

            it 'should get 403 with appropriate error description' do
              update_service_instance(200, headers: headers_for(user), body: body)

              expect(last_response).to have_status_code(403)
              expect(a_request(:update, update_url(service_instance))).not_to have_been_made

              parsed_response = JSON.parse(last_response.body)
              expect(parsed_response).to include(
                'error_code' => 'CF-ServiceInstanceWithInaccessiblePlanNotUpdateable',
                'description' => match(/Cannot update parameters of a service instance that belongs to inaccessible plan/)
              )
            end
          end

          context 'when updating CC attributes' do
            let(:body) do
              {
                name: 'my-new-service-instance',
                tags: ['db']
              }
            end

            it 'should update the instance attributes and not call the broker' do
              update_service_instance(200, headers: headers_for(user), body: body)

              expect(last_response).to have_status_code(201)
              expect(a_request(:any, update_url(service_instance))).not_to have_been_made

              parsed_response = JSON.parse(last_response.body)
              expect(parsed_response['entity']).to include(
                'name' => body[:name],
                'tags' => body[:tags]
              )
            end
          end

          context 'when updating to a plan that is not visible' do
            let(:new_service_plan) { ServicePlan.make(public: false, active: false, service: service_instance.service) }
            let(:body) do
              {
                service_plan_guid: new_service_plan.guid
              }
            end

            it 'should get 403 with appropriate error description' do
              update_service_instance(200, headers: headers_for(user), body: body)

              expect(last_response).to have_status_code(403)
              expect(a_request(:update, update_url(service_instance))).not_to have_been_made

              parsed_response = JSON.parse(last_response.body)
              expect(parsed_response).to include(
                'error_code' => 'CF-NotAuthorized',
                'description' => match(/You are not authorized to perform the requested action/)
              )
            end
          end
        end
      end
    end
  end
end
