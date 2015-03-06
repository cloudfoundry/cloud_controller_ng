require 'spec_helper'

module VCAP::CloudController
  describe SecurityGroupAccess, type: :access do
    subject(:access) { SecurityGroupAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }
    let(:space) { Space.make }
    let(:user) { User.make }
    let(:object) { SecurityGroup.make(space_guids: [space.guid]) }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'admin' do
      it_should_behave_like :admin_full_access
    end

    context 'non admin' do
      context 'when the user is a developer' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it_should_behave_like :read_only
      end

      context 'when the user is not a developer of the owning space' do
        it_should_behave_like :no_access
      end
    end
  end
end
