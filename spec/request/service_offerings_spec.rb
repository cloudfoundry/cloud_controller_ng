require 'spec_helper'
require 'models/services/service_plan'

RSpec.describe 'V3 service offerings' do
  let(:user) { VCAP::CloudController::User.make }

  describe 'GET /v3/service_offerings/:guid' do
    let(:guid) { 'service-offering-guid' }

    context 'when service plan is not available in any orgs' do
      context 'when user is admin' do
        let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
        let(:service_offering) { service_plan.service }
        let(:guid) { service_offering.guid }

        it 'renders a service offering' do
          get "/v3/service_offerings/#{guid}", nil, admin_headers

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to eq({
            'guid' => guid
          })
        end
      end

      context 'when user is not a global read role' do
        # TODO
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
          expect(parsed_response).to eq({
            'guid' => guid
          })
        end
      end

      context 'anonymously' do
        it 'renders a service offering' do
          get "/v3/service_offerings/#{guid}"

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to eq({
            'guid' => guid
          })
        end
      end
    end

    context 'when a service offering plan is available only in some orgs' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
      let!(:service_plan_visibility) do
        VCAP::CloudController::ServicePlanVisibility.make(
          service_plan: service_plan,
          organization: org
        )
      end

      context 'when user has access to one of these orgs' do
        before do
          org.add_user(user)
        end

        it 'responds with not found' do
          get "/v3/service_offerings/#{guid}", nil, headers_for(user)

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to eq({
            'guid' => guid
          })
        end
      end

      context 'when user does not have access to any of these orgs' do
        it 'responds with not found' do
          get "/v3/service_offerings/#{guid}", nil, headers_for(user)

          expect(last_response).to have_status_code(404)
        end
      end
    end
  end
end