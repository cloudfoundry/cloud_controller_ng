require 'spec_helper'
require 'actions/security_group_unapply'

module VCAP::CloudController
  RSpec.describe SecurityGroupUnapply do
    describe '#unapply_running' do
      subject { SecurityGroupUnapply }

      let(:space) { VCAP::CloudController::Space.make }
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }

      before do
        security_group.add_space(space)
      end

      context 'when unapplying a security group from a space' do
        it 'removes the space from the security group' do
          expect {
            subject.unapply_running(security_group, space)
          }.to change { security_group.spaces.count }.by(-1)

          expect(security_group.spaces.count).to eq(0)
        end
      end

      context 'when a model validation fails' do
        before do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          allow(security_group).to receive(:remove_space).and_raise(Sequel::ValidationFailed.new(errors))
        end

        it 'raises an error' do
          expect {
            subject.unapply_running(security_group, space)
          }.to raise_error(SecurityGroupUnapply::Error, 'blork is busted')
        end
      end
    end

    describe '#unapply_staging' do
      subject { SecurityGroupUnapply }

      let(:space) { VCAP::CloudController::Space.make }
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }

      before do
        security_group.add_staging_space(space)
      end

      context 'when unapplying a security group from a space' do
        it 'removes the space from the security group' do
          expect {
            subject.unapply_staging(security_group, space)
          }.to change { security_group.staging_spaces.count }.by(-1)

          expect(security_group.staging_spaces.count).to eq(0)
        end
      end

      context 'when a model validation fails' do
        before do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          allow(security_group).to receive(:remove_staging_space).and_raise(Sequel::ValidationFailed.new(errors))
        end

        it 'raises an error' do
          expect {
            subject.unapply_staging(security_group, space)
          }.to raise_error(SecurityGroupUnapply::Error, 'blork is busted')
        end
      end
    end
  end
end
