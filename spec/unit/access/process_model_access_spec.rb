require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ProcessModelAccess, type: :access do
    subject(:access) { ProcessModelAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:object) { VCAP::CloudController::ProcessModelFactory.make(space:) }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'admin' do
      include_context 'admin setup'

      before { FeatureFlag.make(name: 'app_bits_upload', enabled: false) }

      it_behaves_like 'full access'

      it 'admin always allowed' do
        expect(subject).to allow_op_on_object(:read_env, object)
        expect(subject).to allow_op_on_object(:upload, object)
      end

      it 'allows the user to :read_permissions' do
        expect(subject).to allow_op_on_object(:read_permissions, object)
      end
    end

    context 'global auditor only' do
      include_context 'global auditor setup'

      before { FeatureFlag.make(name: 'app_bits_upload', enabled: false) }

      it_behaves_like 'read only access'

      it 'does NOT allow the user to :read_permissions' do
        expect(subject).not_to allow_op_on_object(:read_permissions, object)
      end

      it 'does NOT allow global_auditor to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'admin read only' do
      include_context 'admin read only setup'

      before { FeatureFlag.make(name: 'app_bits_upload', enabled: false) }

      it_behaves_like 'read only access'

      it 'allows the user to :read_permissions' do
        expect(subject).to allow_op_on_object(:read_permissions, object)
      end

      it 'does allows admin_read_only to :read_env' do
        expect(subject).to allow_op_on_object(:read_env, object)
      end
    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end

      it_behaves_like 'full access'

      it 'allows user to :read_env' do
        expect(subject).to allow_op_on_object(:read_env, object)
      end

      it 'allows user change the diego flag' do
        expect { subject.read_for_update?(object, { 'diego' => true }) }.not_to raise_error
      end

      it 'allows the user to :read_permissions' do
        expect(subject).to allow_op_on_object(:read_permissions, object)
      end

      context 'app_bits_upload FeatureFlag' do
        it 'disallows when enabled' do
          FeatureFlag.make(name: 'app_bits_upload', enabled: false, error_message: nil)
          expect { subject.upload?(object) }.to raise_error(CloudController::Errors::ApiError, /app_bits_upload/)
        end
      end

      context 'when the organization is suspended' do
        before { object.space.organization.status = 'suspended' }

        it_behaves_like 'read only access'
      end

      context 'when the app_scaling feature flag is disabled' do
        before { FeatureFlag.make(name: 'app_scaling', enabled: false, error_message: nil) }

        it 'cannot scale' do
          expect { subject.read_for_update?(object, { 'memory' => 2 }) }.to raise_error(CloudController::Errors::ApiError, /app_scaling/)
          expect { subject.read_for_update?(object, { 'disk_quota' => 2 }) }.to raise_error(CloudController::Errors::ApiError, /app_scaling/)
          expect { subject.read_for_update?(object, { 'instances' => 2 }) }.to raise_error(CloudController::Errors::ApiError, /app_scaling/)
        end

        it 'allows unchanged fields to be specified' do
          expect { subject.read_for_update?(object, { 'instances' => 1 }) }.not_to raise_error
        end

        it 'allows changing other fields' do
          expect(subject).to be_read_for_update(object, { 'buildpack' => 'http://foo.git' })
        end
      end
    end

    context 'organization manager' do
      before { org.add_manager(user) }

      it_behaves_like 'read only access'

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end

      it 'does not allow the user to :read_permissions' do
        expect(subject).not_to allow_op_on_object(:read_permissions, object)
      end
    end

    context 'organization user' do
      before { org.add_user(user) }

      it_behaves_like 'no access'

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end

      it 'does not allow the user to :read_permissions' do
        expect(subject).not_to allow_op_on_object(:read_permissions, object)
      end
    end

    context 'organization auditor' do
      before { org.add_auditor(user) }

      it_behaves_like 'no access'

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end

      it 'does not allow the user to :read_permissions' do
        expect(subject).not_to allow_op_on_object(:read_permissions, object)
      end
    end

    context 'billing manager' do
      before { org.add_billing_manager(user) }

      it_behaves_like 'no access'

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end

      it 'does not allow the user to :read_permissions' do
        expect(subject).not_to allow_op_on_object(:read_permissions, object)
      end
    end

    context 'space manager' do
      before do
        org.add_user(user)
        space.add_manager(user)
      end

      it_behaves_like 'read only access'

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end

      it 'does not allow the user to :read_permissions' do
        expect(subject).not_to allow_op_on_object(:read_permissions, object)
      end
    end

    context 'space auditor' do
      before do
        org.add_user(user)
        space.add_auditor(user)
      end

      it_behaves_like 'read only access'

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end

      it 'does not allow the user to :read_permissions' do
        expect(subject).not_to allow_op_on_object(:read_permissions, object)
      end
    end

    context 'any user using client without cloud_controller.write' do
      let(:token) { { 'scope' => ['cloud_controller.read'] } }

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        space.add_manager(user)
        space.add_developer(user)
        space.add_auditor(user)
      end

      it_behaves_like 'read only access'
    end

    context 'any user using client without cloud_controller.read' do
      let(:token) { { 'scope' => [] } }

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        space.add_manager(user)
        space.add_developer(user)
        space.add_auditor(user)
      end

      it_behaves_like 'no access'
    end

    context 'handles concurrent deletion of app' do
      let(:object) { VCAP::CloudController::ProcessModelFactory.make(space: nil) }

      # only using global_auditor as an example of a non-admin user
      include_context 'global auditor setup'

      before do
        allow(object).to receive(:in_suspended_org?).and_return(false)
      end

      it 'does NOT allow global_auditor to create' do
        expect(subject).not_to be_create(object)
      end

      it 'does NOT allow global_auditor to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end

      it 'does NOT allow the user to :read_permissions' do
        expect(subject).not_to allow_op_on_object(:read_permissions, object)
      end
    end
  end
end
