require 'spec_helper'
require 'actions/role_delete'

module VCAP::CloudController
  RSpec.describe RoleDeleteAction do
    subject { RoleDeleteAction.new }

    describe '#delete' do
      shared_examples 'deletion' do
        it 'deletes the correct role' do
          dataset = Role.where(guid: role.guid)
          expect {
            subject.delete(dataset)
          }.to change { Role.count }.by(-1)
          expect { role.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end

      context 'space auditor' do
        let!(:role) { SpaceAuditor.make }
        it_behaves_like 'deletion'
      end

      context 'space manager' do
        let!(:role) { SpaceManager.make }
        it_behaves_like 'deletion'
      end

      context 'space developer' do
        let!(:role) { SpaceDeveloper.make }
        it_behaves_like 'deletion'
      end

      context 'org manager' do
        let!(:role) { OrganizationManager.make }
        it_behaves_like 'deletion'
      end

      context 'org billing manager' do
        let!(:role) { OrganizationBillingManager.make }
        it_behaves_like 'deletion'
      end

      context 'org auditor' do
        let!(:role) { OrganizationAuditor.make }
        it_behaves_like 'deletion'
      end

      context 'org user' do
        let!(:role) { OrganizationUser.make }
        it_behaves_like 'deletion'
      end
    end
  end
end
