require 'spec_helper'

module VCAP::CloudController
  describe ServiceBrokerAccess, type: :access do
    subject(:access) { ServiceBrokerAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:app) { VCAP::CloudController::AppFactory.make(space: space) }
    let(:object) { VCAP::CloudController::ServiceBroker.make }
    let(:broker_with_space) { VCAP::CloudController::ServiceBroker.make space: space }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'admin' do
      include_context :admin_setup
      it_behaves_like :full_access

      context 'when FeatureFlag space_scoped_private_broker_creation is false' do
        before { FeatureFlag.make(name: 'space_scoped_private_broker_creation', enabled: false, error_message: nil) }

        it_behaves_like :full_access
      end
    end

    context 'organization manager (defensive)' do
      before { org.add_manager(user) }
      it_behaves_like :no_access
      it { is_expected.to allow_op_on_object :index, VCAP::CloudController::ServiceBroker }
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }
      it_behaves_like :no_access
      it { is_expected.to allow_op_on_object :index, VCAP::CloudController::ServiceBroker }
    end

    context 'space developer' do
      before do
        org.add_user user
        space.add_developer user
      end
      it_behaves_like :no_access

      context 'when FeatureFlag space_scoped_private_broker_creation is true' do
        before { FeatureFlag.make(name: 'space_scoped_private_broker_creation', enabled: true, error_message: nil) }
        it { is_expected.to allow_op_on_object :create, broker_with_space }
      end

      context 'when FeatureFlag space_scoped_private_broker_creation is false' do
        before { FeatureFlag.make(name: 'space_scoped_private_broker_creation', enabled: false, error_message: nil) }

        it 'does not allow the create' do
          expect { subject.create?(broker_with_space) }.to raise_error(VCAP::Errors::ApiError, /space_scoped_private_broker_creation/)
        end
      end

      it { is_expected.to allow_op_on_object :update, broker_with_space }
      it { is_expected.to allow_op_on_object :delete, broker_with_space }
      it { is_expected.to allow_op_on_object :index, VCAP::CloudController::ServiceBroker }
    end

    context 'space manager' do
      before do
        org.add_user user
        space.add_manager user
      end
      it_behaves_like :no_access
      it { is_expected.to_not allow_op_on_object :update, broker_with_space }
      it { is_expected.to_not allow_op_on_object :delete, broker_with_space }
      it { is_expected.to allow_op_on_object :index, VCAP::CloudController::ServiceBroker }
    end

    context 'space auditor' do
      before do
        org.add_user user
        space.add_auditor user
      end
      it_behaves_like :no_access
      it { is_expected.to_not allow_op_on_object :update, broker_with_space }
      it { is_expected.to_not allow_op_on_object :delete, broker_with_space }
      it { is_expected.to allow_op_on_object :index, VCAP::CloudController::ServiceBroker }
    end

    context 'unassociated user' do
      it_behaves_like :no_access
      it { is_expected.to allow_op_on_object :index, VCAP::CloudController::ServiceBroker }
    end

    context 'user in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_user(user)
      end

      it_behaves_like :no_access
      it { is_expected.to allow_op_on_object :index, VCAP::CloudController::ServiceBroker }
    end

    context 'manager in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_manager(user)
      end

      it_behaves_like :no_access
      it { is_expected.to allow_op_on_object :index, VCAP::CloudController::ServiceBroker }
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      it_behaves_like :no_access
      it { is_expected.to allow_op_on_object :index, VCAP::CloudController::ServiceBroker }
    end
  end
end
