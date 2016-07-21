require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppAccess, type: :access do
    subject(:access) { AppAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:object) { VCAP::CloudController::AppFactory.make(space: space) }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'admin' do
      include_context :admin_setup

      before { FeatureFlag.make(name: 'app_bits_upload', enabled: false) }

      it_behaves_like :full_access

      it 'admin always allowed' do
        expect(subject).to allow_op_on_object(:read_env, object)
        expect(subject).to allow_op_on_object(:upload, object)
      end

      context 'when the space changes' do
        it 'succeeds when not developer in the new space' do
          object.space = Space.make
          expect(subject.update?(object, nil)).to be_truthy
        end
      end
    end

    context 'admin read only' do
      include_context :admin_read_only_setup

      before { FeatureFlag.make(name: 'app_bits_upload', enabled: false) }

      it_behaves_like :read_only_access

      it 'does allows admin_read_only to :read_env' do
        expect(subject).to allow_op_on_object(:read_env, object)
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

      it 'allows user change the diego flag' do
        expect { subject.read_for_update?(object, { 'diego' => true }) }.not_to raise_error
      end

      context 'app_bits_upload FeatureFlag' do
        it 'disallows when enabled' do
          FeatureFlag.make(name: 'app_bits_upload', enabled: false, error_message: nil)
          expect { subject.upload?(object) }.to raise_error(CloudController::Errors::ApiError, /app_bits_upload/)
        end
      end

      context 'when the organization is suspended' do
        before { object.space.organization.status = 'suspended' }
        it_behaves_like :read_only_access
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

      context 'when the app_scaling feature flag is disabled' do
        before { FeatureFlag.make(name: 'app_scaling', enabled: false, error_message: nil) }

        it 'cannot scale' do
          expect { subject.read_for_update?(object, { 'memory' => 2 }) }.to raise_error(CloudController::Errors::ApiError, /app_scaling/)
          expect { subject.read_for_update?(object, { 'disk_quota' => 2 }) }.to raise_error(CloudController::Errors::ApiError, /app_scaling/)
          expect { subject.read_for_update?(object, { 'instances' => 2 }) }.to raise_error(CloudController::Errors::ApiError, /app_scaling/)
        end

        it 'allows unchanged fields to be specified' do
          expect { subject.read_for_update?(object, { 'instances' => 1 }) }.to_not raise_error
        end

        it 'allows changing other fields' do
          expect(subject.read_for_update?(object, { 'buildpack' => 'http://foo.git' })).to be_truthy
        end
      end

      context 'when the users_can_select_backend config value is disabled' do
        before { TestConfig.override(users_can_select_backend: false) }

        it 'does not allow user to change the diego flag' do
          expect { subject.read_for_update?(object, { 'diego' => true }) }.to raise_error(CloudController::Errors::ApiError, /backend/)
        end
      end
    end

    context 'organization manager' do
      before { org.add_manager(user) }
      it_behaves_like :read_only_access

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
      it_behaves_like :read_only_access

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'space auditor' do
      before do
        org.add_user(user)
        space.add_auditor(user)
      end
      it_behaves_like :read_only_access

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
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

      it_behaves_like :read_only_access
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

      it_behaves_like :no_access
    end
  end
end
