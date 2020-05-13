require 'spec_helper'
require 'presenters/v3/role_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RolePresenter do
    subject(:presenter) { RolePresenter.new(role) }

    describe '#to_hash' do
      describe 'the role is space auditor' do
        let(:role) { VCAP::CloudController::SpaceAuditor.make }
        let(:result) { presenter.to_hash }

        it 'presents the role' do
          expect(result[:guid]).to eq(role.guid)
          expect(result[:created_at]).to eq(role.created_at)
          expect(result[:updated_at]).to eq(role.updated_at)
          expect(result[:type]).to eq('space_auditor')
          expect(result[:relationships][:user][:data][:guid]).to eq(role.user.guid)
          expect(result[:relationships][:space][:data][:guid]).to eq(role.space.guid)
          expect(result[:relationships][:organization][:data]).to be_nil
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/roles/#{role.guid}")
          expect(result[:links][:user][:href]).to eq("#{link_prefix}/v3/users/#{role.user.guid}")
          expect(result[:links][:space][:href]).to eq("#{link_prefix}/v3/spaces/#{role.space.guid}")
        end
      end
      describe 'the role is space developer' do
        let(:role) { VCAP::CloudController::SpaceDeveloper.make }
        let(:result) { presenter.to_hash }

        it 'presents the role' do
          expect(result[:guid]).to eq(role.guid)
          expect(result[:created_at]).to eq(role.created_at)
          expect(result[:updated_at]).to eq(role.updated_at)
          expect(result[:type]).to eq('space_developer')
          expect(result[:relationships][:user][:data][:guid]).to eq(role.user.guid)
          expect(result[:relationships][:space][:data][:guid]).to eq(role.space.guid)
          expect(result[:relationships][:organization][:data]).to be_nil
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/roles/#{role.guid}")
          expect(result[:links][:user][:href]).to eq("#{link_prefix}/v3/users/#{role.user.guid}")
          expect(result[:links][:space][:href]).to eq("#{link_prefix}/v3/spaces/#{role.space.guid}")
        end
      end
      describe 'the role is space developer' do
        let(:role) { VCAP::CloudController::SpaceManager.make }
        let(:result) { presenter.to_hash }

        it 'presents the role' do
          expect(result[:guid]).to eq(role.guid)
          expect(result[:created_at]).to eq(role.created_at)
          expect(result[:updated_at]).to eq(role.updated_at)
          expect(result[:type]).to eq('space_manager')
          expect(result[:relationships][:user][:data][:guid]).to eq(role.user.guid)
          expect(result[:relationships][:space][:data][:guid]).to eq(role.space.guid)
          expect(result[:relationships][:organization][:data]).to be_nil
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/roles/#{role.guid}")
          expect(result[:links][:user][:href]).to eq("#{link_prefix}/v3/users/#{role.user.guid}")
          expect(result[:links][:space][:href]).to eq("#{link_prefix}/v3/spaces/#{role.space.guid}")
        end
      end
      describe 'the role is organization auditor' do
        let(:role) { VCAP::CloudController::OrganizationAuditor.make }
        let(:result) { presenter.to_hash }

        it 'presents the role' do
          expect(result[:guid]).to eq(role.guid)
          expect(result[:created_at]).to eq(role.created_at)
          expect(result[:updated_at]).to eq(role.updated_at)
          expect(result[:type]).to eq('organization_auditor')
          expect(result[:relationships][:user][:data][:guid]).to eq(role.user.guid)
          expect(result[:relationships][:organization][:data][:guid]).to eq(role.organization.guid)
          expect(result[:relationships][:space][:data]).to be_nil
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/roles/#{role.guid}")
          expect(result[:links][:user][:href]).to eq("#{link_prefix}/v3/users/#{role.user.guid}")
          expect(result[:links][:organization][:href]).to eq("#{link_prefix}/v3/organizations/#{role.organization.guid}")
        end
      end
      describe 'the role is organization manager' do
        let(:role) { VCAP::CloudController::OrganizationManager.make }
        let(:result) { presenter.to_hash }

        it 'presents the role' do
          expect(result[:guid]).to eq(role.guid)
          expect(result[:created_at]).to eq(role.created_at)
          expect(result[:updated_at]).to eq(role.updated_at)
          expect(result[:type]).to eq('organization_manager')
          expect(result[:relationships][:user][:data][:guid]).to eq(role.user.guid)
          expect(result[:relationships][:organization][:data][:guid]).to eq(role.organization.guid)
          expect(result[:relationships][:space][:data]).to be_nil
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/roles/#{role.guid}")
          expect(result[:links][:user][:href]).to eq("#{link_prefix}/v3/users/#{role.user.guid}")
          expect(result[:links][:organization][:href]).to eq("#{link_prefix}/v3/organizations/#{role.organization.guid}")
        end
      end
      describe 'the role is organization billing manager' do
        let(:role) { VCAP::CloudController::OrganizationBillingManager.make }
        let(:result) { presenter.to_hash }

        it 'presents the role' do
          expect(result[:guid]).to eq(role.guid)
          expect(result[:created_at]).to eq(role.created_at)
          expect(result[:updated_at]).to eq(role.updated_at)
          expect(result[:type]).to eq('organization_billing_manager')
          expect(result[:relationships][:user][:data][:guid]).to eq(role.user.guid)
          expect(result[:relationships][:organization][:data][:guid]).to eq(role.organization.guid)
          expect(result[:relationships][:space][:data]).to be_nil
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/roles/#{role.guid}")
          expect(result[:links][:user][:href]).to eq("#{link_prefix}/v3/users/#{role.user.guid}")
          expect(result[:links][:organization][:href]).to eq("#{link_prefix}/v3/organizations/#{role.organization.guid}")
        end
      end
      describe 'the role is organization user' do
        let(:role) { VCAP::CloudController::OrganizationUser.make }
        let(:result) { presenter.to_hash }

        it 'presents the role' do
          expect(result[:guid]).to eq(role.guid)
          expect(result[:created_at]).to eq(role.created_at)
          expect(result[:updated_at]).to eq(role.updated_at)
          expect(result[:type]).to eq('organization_user')
          expect(result[:relationships][:user][:data][:guid]).to eq(role.user.guid)
          expect(result[:relationships][:organization][:data][:guid]).to eq(role.organization.guid)
          expect(result[:relationships][:space][:data]).to be_nil
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/roles/#{role.guid}")
          expect(result[:links][:user][:href]).to eq("#{link_prefix}/v3/users/#{role.user.guid}")
          expect(result[:links][:organization][:href]).to eq("#{link_prefix}/v3/organizations/#{role.organization.guid}")
        end
      end

      describe 'when the user guid is weird' do
        let(:user) { VCAP::CloudController::User.make(guid: ':---)') }
        let(:role) { VCAP::CloudController::SpaceAuditor.make(user: user) }
        let(:result) { presenter.to_hash }

        it 'presents the role' do
          expect(result[:links][:user][:href]).to eq("#{link_prefix}/v3/users/#{CGI.escape(role.user_guid)}")
        end
      end
    end
  end
end
