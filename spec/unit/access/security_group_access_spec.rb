require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SecurityGroupAccess, type: :access do
    subject(:access) { SecurityGroupAccess.new(Security::AccessContext.new) }
    let(:space) { Space.make }
    let(:user) { User.make }
    let(:object) { SecurityGroup.make(space_guids: [space.guid]) }

    before { set_current_user(user) }

    it_behaves_like 'admin read only access'

    context 'admin' do
      it_behaves_like 'admin full access'
    end

    context 'non admin' do
      context 'when the user is a developer' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it_behaves_like 'read only access'
      end

      context 'when the user is not a developer of the owning space' do
        it_behaves_like 'no access'
      end
    end
  end
end
