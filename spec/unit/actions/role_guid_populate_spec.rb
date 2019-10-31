require 'spec_helper'
require 'actions/role_guid_populate'

module VCAP::CloudController
  RSpec.describe RoleGuidPopulate do
    subject { RoleGuidPopulate }

    before do
      role_without_guid.update(role_guid: nil)
    end

    context 'organization_auditor' do
      let(:role_with_guid) { OrganizationAuditor.make }
      let(:role_without_guid) { OrganizationAuditor.make }

      it 'fills in guids for roles that do not have guids' do
        existing_guid = role_with_guid.guid
        expect(existing_guid).to be_a_guid
        expect(role_without_guid.guid).to be_nil

        subject.populate

        expect(role_with_guid.reload.guid).to eq(existing_guid)
        expect(role_without_guid.reload.guid).to be_a_guid
      end
    end

    context 'organization_user' do
      let(:role_with_guid) { OrganizationUser.make }
      let(:role_without_guid) { OrganizationUser.make }

      it 'fills in guids for roles that do not have guids' do
        existing_guid = role_with_guid.guid
        expect(existing_guid).to be_a_guid
        expect(role_without_guid.guid).to be_nil

        subject.populate

        expect(role_with_guid.reload.guid).to eq(existing_guid)
        expect(role_without_guid.reload.guid).to be_a_guid
      end
    end

    context 'organization_manager' do
      let(:role_with_guid) { OrganizationManager.make }
      let(:role_without_guid) { OrganizationManager.make }

      it 'fills in guids for roles that do not have guids' do
        existing_guid = role_with_guid.guid
        expect(existing_guid).to be_a_guid
        expect(role_without_guid.guid).to be_nil

        subject.populate

        expect(role_with_guid.reload.guid).to eq(existing_guid)
        expect(role_without_guid.reload.guid).to be_a_guid
      end
    end

    context 'organization_billing_manager' do
      let(:role_with_guid) { OrganizationBillingManager.make }
      let(:role_without_guid) { OrganizationBillingManager.make }

      it 'fills in guids for roles that do not have guids' do
        existing_guid = role_with_guid.guid
        expect(existing_guid).to be_a_guid
        expect(role_without_guid.guid).to be_nil

        subject.populate

        expect(role_with_guid.reload.guid).to eq(existing_guid)
        expect(role_without_guid.reload.guid).to be_a_guid
      end
    end

    context 'space_auditor' do
      let(:role_with_guid) { SpaceAuditor.make }
      let(:role_without_guid) { SpaceAuditor.make }

      it 'fills in guids for roles that do not have guids' do
        existing_guid = role_with_guid.guid
        expect(existing_guid).to be_a_guid
        expect(role_without_guid.guid).to be_nil

        subject.populate

        expect(role_with_guid.reload.guid).to eq(existing_guid)
        expect(role_without_guid.reload.guid).to be_a_guid
      end
    end

    context 'space_manager' do
      let(:role_with_guid) { SpaceManager.make }
      let(:role_without_guid) { SpaceManager.make }

      it 'fills in guids for roles that do not have guids' do
        existing_guid = role_with_guid.guid
        expect(existing_guid).to be_a_guid
        expect(role_without_guid.guid).to be_nil

        subject.populate

        expect(role_with_guid.reload.guid).to eq(existing_guid)
        expect(role_without_guid.reload.guid).to be_a_guid
      end
    end

    context 'space_developer' do
      let(:role_with_guid) { SpaceDeveloper.make }
      let(:role_without_guid) { SpaceDeveloper.make }

      it 'fills in guids for roles that do not have guids' do
        existing_guid = role_with_guid.guid
        expect(existing_guid).to be_a_guid
        expect(role_without_guid.guid).to be_nil

        subject.populate

        expect(role_with_guid.reload.guid).to eq(existing_guid)
        expect(role_without_guid.reload.guid).to be_a_guid
      end
    end
  end
end
