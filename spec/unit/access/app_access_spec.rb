require 'spec_helper'

module VCAP::CloudController
  describe AppAccess, type: :access do
    subject(:access) { AppAccess.new(Security::AccessContext.new) }
    let(:token) {{ 'scope' => ['cloud_controller.read', 'cloud_controller.write'] }}
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(:organization => org) }
    let(:object) { VCAP::CloudController::AppFactory.make(:space => space) }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'admin' do
      include_context :admin_setup

      it_behaves_like :full_access

      it 'allows user to :read_env' do
        expect(subject).to allow_op_on_object(:read_env, object)
      end

      context 'when the space changes' do
        it 'succeeds when not developer in the new space' do
          object.space = Space.make
          expect(subject.update?(object, nil)).to be_truthy
        end
      end

    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end
      it_behaves_like :full_access

      it 'allows user to :read_env' do
        expect(subject).to allow_op_on_object(:read_env, object)
      end

      context 'when the organization is suspended' do
        before { object.space.organization.status = 'suspended' }
        it_behaves_like :read_only
      end

      context 'when the space changes' do
        it 'succeeds as a developer in the new space' do
          object.space = Space.make(organization: org)
          object.space.add_developer(user)
          expect(subject.update?(object, nil)).to be_truthy
        end

        it 'fails when not developer in the new space' do
          object.space = Space.make
          expect(subject.update?(object, nil)).to be_falsey
        end
      end
    end

    context 'organization manager' do
      before { org.add_manager(user) }
      it_behaves_like :read_only

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'organization user' do
      before { org.add_user(user) }
      it_behaves_like :no_access

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'organization auditor' do
      before { org.add_auditor(user) }
      it_behaves_like :no_access

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'billing manager' do
      before { org.add_billing_manager(user) }
      it_behaves_like :no_access

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'space manager' do
      before do
        org.add_user(user)
        space.add_manager(user)
      end
      it_behaves_like :read_only

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'space auditor' do
      before do
        org.add_user(user)
        space.add_auditor(user)
      end
      it_behaves_like :read_only

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'any user using client without cloud_controller.write' do
      let(:token) {{'scope' => ['cloud_controller.read']}}

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        space.add_manager(user)
        space.add_developer(user)
        space.add_auditor(user)
      end

      it_behaves_like :read_only
    end

    context 'any user using client without cloud_controller.read' do
      let(:token) {{'scope' => []}}

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        space.add_manager(user)
        space.add_developer(user)
        space.add_auditor(user)
      end

      it_behaves_like :no_access
    end
  end
end
