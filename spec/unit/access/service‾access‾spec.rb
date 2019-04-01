require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceAccess, type: :access do
    subject(:access) { ServiceAccess.new(Security::AccessContext.new) }
    let(:user) { VCAP::CloudController::User.make }
    let!(:service_plan) { VCAP::CloudController::ServicePlan.make(service: object) }
    let(:object) { VCAP::CloudController::Service.make }

    it_behaves_like :admin_full_access
    it_behaves_like :admin_read_only_access

    context 'for a logged in user' do
      before { set_current_user(user) }

      it_behaves_like :read_only_access
    end

    context 'any user using client without cloud_controller.read' do
      before { set_current_user(user, scopes: []) }

      it_behaves_like :no_access
    end

    context 'space developer' do
      let(:space) { Space.make }

      before do
        set_current_user(user)
        space.organization.add_user user
        space.add_developer user
      end

      it_behaves_like :read_only_access

      context 'when the broker for the service is space scoped' do
        before do
          broker = object.service_broker
          broker.space = space
          broker.save
        end

        it { is_expected.to allow_op_on_object :delete, object }
      end
    end
  end
end
