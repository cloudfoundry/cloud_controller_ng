require 'spec_helper'
require 'actions/space_quota_unapply'

module VCAP::CloudController
  RSpec.describe SpaceQuotaUnapply do
    describe '#unapply' do
      subject { SpaceQuotaUnapply }

      let(:org) { VCAP::CloudController::Organization.make }
      let(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org) }
      let!(:space) { VCAP::CloudController::Space.make(organization: org, space_quota_definition: space_quota) }

      context 'when removing a quota from a space' do
        it 'disassociates the given space from the quota' do
          expect(space_quota.spaces[0].guid).to eq(space.guid)
          expect {
            subject.unapply(space_quota, space)
          }.to change { space_quota.spaces.count }.by(-1)

          expect(space_quota.spaces.count).to eq(0)
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(space_quota).to receive(:remove_space).and_raise(Sequel::ValidationFailed.new(errors))

          expect {
            subject.unapply(space_quota, space)
          }.to raise_error(SpaceQuotaUnapply::Error, 'blork is busted')
        end
      end
    end
  end
end
