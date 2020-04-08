require 'spec_helper'
require 'actions/security_group_delete'

module VCAP::CloudController
  RSpec.describe SecurityGroupDeleteAction do
    subject(:security_group_delete) { SecurityGroupDeleteAction.new }

    describe '#delete' do
      let!(:security_group) { SecurityGroup.make(name: 'test-security-group') }

      it 'deletes the security group record' do
        expect {
          security_group_delete.delete([security_group])
        }.to change { SecurityGroup.count }.by(-1)
        expect { security_group.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      describe 'recursive deletion' do
        let(:space) { Space.make(name: 'petunia') }

        before do
          security_group.add_space(space)
          security_group.add_staging_space(space)
        end

        it 'deletes associated running spaces roles' do
          expect {
            security_group_delete.delete([security_group])
          }.to change { space.reload.security_groups.count }.by(-1)
        end

        it 'deletes associated staging spaces roles' do
          expect {
            security_group_delete.delete([security_group])
          }.to change { space.reload.staging_security_groups.count }.by(-1)
        end
      end
    end
  end
end
