require 'spec_helper'
require 'actions/set_default_isolation_segment'

module VCAP::CloudController
  RSpec.describe SetDefaultIsolationSegment do
    subject(:set_default_isolation_segment) { SetDefaultIsolationSegment.new }

    let(:org) { VCAP::CloudController::Organization.make }
    let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'JB') }
    let(:isolation_segment_guid) { isolation_segment.guid }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
    let(:message) do
      VCAP::CloudController::OrgDefaultIsoSegUpdateMessage.new(
        {
          data: { guid: isolation_segment_guid }
        }
      )
    end

    describe '#set' do
      context 'when the org is entitled to the isolation segment' do
        before do
          assigner.assign(isolation_segment, [org])
        end

        it 'updates the default iso seg guid on the organization' do
          expect(org.default_isolation_segment_guid).to be_nil
          set_default_isolation_segment.set(org, isolation_segment, message)

          org.reload
          expect(org.default_isolation_segment_guid).to eq(isolation_segment.guid)
        end

        context 'when no changes are requested' do
          let(:message) { OrgDefaultIsoSegUpdateMessage.new({}) }

          it 'does not update the org' do
            expect(org.default_isolation_segment_guid).to be_nil
            set_default_isolation_segment.set(org, isolation_segment, message)

            org.reload
            expect(org.default_isolation_segment_guid).to be_nil
          end
        end
      end

      context 'when the org is NOT entitled to the isolation segment' do
        it 'raises an invalid relationship error' do
          expect {
            set_default_isolation_segment.set(org, isolation_segment, message)
          }.to raise_error VCAP::CloudController::SetDefaultIsolationSegment::Error, /Unable to assign/
        end
      end

      context 'when the isolation segment does not exist' do
        let(:isolation_segment) { nil }
        let(:isolation_segment_guid) { 'guid' }

        it 'raises an invalid relationship error' do
          expect {
            set_default_isolation_segment.set(org, isolation_segment, message)
          }.to raise_error VCAP::CloudController::SetDefaultIsolationSegment::Error, /Unable to assign/
        end
      end

      context 'when the isolation segment guid is null' do
        let(:isolation_segment_guid) { nil }

        context 'when the org already has an assigned isolation segment' do
          before do
            other_iso_seg = IsolationSegmentModel.make
            assigner.assign(other_iso_seg, [org])
            org.update(default_isolation_segment_guid: other_iso_seg.guid)
            expect(org.default_isolation_segment_guid).to_not be_nil
          end

          it 'sets the default isolation segment to null' do
            set_default_isolation_segment.set(org, nil, message)

            org.reload
            expect(org.default_isolation_segment_guid).to be_nil
          end
        end
      end

      context 'when the org is invalid' do
        before do
          assigner.assign(isolation_segment, [org])
          allow(org).to receive(:save).and_raise(Sequel::ValidationFailed.new('some message'))
        end

        it 'raises an InvalidOrg error' do
          expect {
            set_default_isolation_segment.set(org, isolation_segment, message)
          }.to raise_error(SetDefaultIsolationSegment::Error, 'some message')
        end
      end
    end
  end
end
