require 'spec_helper'

module VCAP::CloudController
  describe ServiceAccess, type: :access do
    subject(:access) { ServiceAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }
    let(:user) { VCAP::CloudController::User.make }
    let!(:service_plan) { VCAP::CloudController::ServicePlan.make(service: object) }
    let(:object) { VCAP::CloudController::Service.make }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    it_should_behave_like :admin_full_access

    context 'for a logged in user' do
      it_behaves_like :read_only_access
    end

    context 'a user that is not logged in' do
      let(:user) { nil }
      it_behaves_like :read_only_access
    end

    context 'any user using client without cloud_controller.read' do
      let(:token) { { 'scope' => [] } }
      it_behaves_like :no_access
    end

    context 'space developer' do
      let(:space) { Space.make }

      before do
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
