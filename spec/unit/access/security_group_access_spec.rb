require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SecurityGroupAccess, type: :access do
    subject(:access) { SecurityGroupAccess.new(Security::AccessContext.new) }
    let(:space) { FactoryBot.create(:space) }
    let(:user) { FactoryBot.create(:user) }
    let(:object) { FactoryBot.create(:security_group, space_guids: [space.guid]) }

    before { set_current_user(user) }

    it_behaves_like :admin_read_only_access

    context 'admin' do
      it_should_behave_like :admin_full_access
    end

    context 'non admin' do
      context 'when the user is a developer' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it_should_behave_like :read_only_access
      end

      context 'when the user is not a developer of the owning space' do
        it_should_behave_like :no_access
      end
    end
  end
end
