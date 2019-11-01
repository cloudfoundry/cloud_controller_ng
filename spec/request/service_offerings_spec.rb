require 'spec_helper'
require 'models/services/service_plan'

RSpec.describe 'V3 service offerings' do
  let(:user) { VCAP::CloudController::User.make }

  describe 'GET /v3/service_offerings/:guid' do
    context 'when service plan is not available in any orgs' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
      let(:service_offering) { service_plan.service }
      let(:guid) { service_offering.guid }

      context 'when user is admin' do
        it 'renders a service offering' do
          get "/v3/service_offerings/#{guid}", nil, admin_headers

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to match(
            hash_including(
              'guid' => guid,
              'name' => service_offering.label,
              'description' => service_offering.description,
              'available' => true,
              'bindable' => true,
              'broker_service_offering_metadata' => service_offering.extra,
              'broker_service_offering_id' => service_offering.unique_id,
              'tags' => [],
              'requires' => [],
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'plan_updateable' => false,
              'shareable' => true,
            )
          )
        end
      end

      context 'when user is not a global read role' do
        it 'responds with not found' do
          get "/v3/service_offerings/#{guid}", nil, headers_for(user)

          expect(last_response).to have_status_code(404)
          expect(parsed_response).to match({
            'errors' => [hash_including(
              'detail' => 'Service offering not found',
              'title' => 'CF-ResourceNotFound',
              'code' => 10010
            )]
          })
        end
      end
    end

    context 'when service offering is globally available' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }
      let(:service_offering) { service_plan.service }
      let(:guid) { service_offering.guid }

      context 'when user is not an admin' do
        it 'renders a service offering' do
          get "/v3/service_offerings/#{guid}", nil, headers_for(user)

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to match(hash_including(
                                             'guid' => guid,
                                             'name' => service_offering.label
          ))
        end
      end

      context 'anonymously' do
        it 'renders a service offering' do
          get "/v3/service_offerings/#{guid}"

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to match(hash_including(
                                             'guid' => guid,
                                             'name' => service_offering.label
          ))
        end
      end
    end

    context 'when a service offering plan is available only in some orgs' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
      let(:service_offering) { service_plan.service }
      let!(:service_plan_visibility) do
        VCAP::CloudController::ServicePlanVisibility.make(
          service_plan: service_plan,
          organization: org
        )
      end
      let(:guid) { service_offering.guid }

      context 'when user has access to one of these orgs' do
        before do
          org.add_user(user)
        end

        it 'renders a service offering' do
          get "/v3/service_offerings/#{guid}", nil, headers_for(user)

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to match(hash_including(
                                             'guid' => guid,
                                             'name' => service_offering.label
          ))
        end
      end

      context 'when user does not have access to any of these orgs' do
        it 'responds with not found' do
          get "/v3/service_offerings/#{guid}", nil, headers_for(user)

          expect(last_response).to have_status_code(404)
          expect(parsed_response).to match({
            'errors' => [hash_including(
              'detail' => 'Service offering not found',
              'title' => 'CF-ResourceNotFound',
              'code' => 10010
            )]
          })
        end
      end

      context 'when service offering comes from space scoped broker' do
        # TODO: Think about this
      end
    end
  end
end
