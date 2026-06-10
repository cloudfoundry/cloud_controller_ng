require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ManagedServiceInstanceAccess, type: :access do
    subject(:access) { ManagedServiceInstanceAccess.new(Security::AccessContext.new) }

    let(:user) { create(:user) }
    let(:org) { create(:organization) }
    let(:space) { create(:space, organization: org) }
    let(:service) { create(:service) }
    let(:service_plan_active) { true }
    let(:service_plan) { create(:service_plan, service: service, active: service_plan_active) }
    let(:object) { create(:managed_service_instance, service_plan:, space:) }

    before { set_current_user(user) }

    it_behaves_like 'admin read only access'

    context 'admin' do
      include_context 'admin setup'
      it_behaves_like 'full access'

      context 'service plan' do
        it 'allowed when the service plan is not visible' do
          new_plan = create(:service_plan, active: false)

          object.service_plan = new_plan
          expect(subject).to be_update(object)
        end
      end
    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end

      context 'service plan' do
        it 'allows when the new service plan is visible' do
          new_plan = create(:service_plan, service:)
          object.service_plan = new_plan
          expect(subject).to be_create(object)
          expect(subject).to be_read_for_update(object)
          expect(subject).to be_update(object)
        end

        it 'fails when assigning to a service plan that is not visible' do
          new_plan = create(:service_plan, active: false)

          object.service_plan = new_plan
          expect(subject).not_to be_update(object)
        end

        context 'when updating from a service plan that is not visible' do
          let(:service_plan) { create(:service_plan, service: service, active: false) }

          it 'succeeds' do
            object.name = 'new name'
            expect(subject).to be_update(object)
          end
        end
      end

      context 'when creating a new service instance' do
        context 'when the plan is visible' do
          it 'allows the create' do
            new_service_instance = VCAP::CloudController::ManagedServiceInstance.new(service_plan:, space:)
            expect(subject).to be_create(new_service_instance)
          end
        end

        context 'when the plan is not visible' do
          let(:service_plan_active) { false }

          it 'does not allow the create' do
            new_service_instance = VCAP::CloudController::ManagedServiceInstance.new(service_plan:, space:)
            expect(subject).not_to be_create(new_service_instance)
          end
        end
      end
    end
  end
end
