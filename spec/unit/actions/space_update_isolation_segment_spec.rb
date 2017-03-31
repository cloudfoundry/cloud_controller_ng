require 'spec_helper'
require 'actions/space_update_isolation_segment'

module VCAP::CloudController
  RSpec.describe SpaceUpdateIsolationSegment do
    subject(:space_update) { SpaceUpdateIsolationSegment.new(user_audit_info) }

    let(:org) { Organization.make }
    let(:space) { Space.make(organization: org) }
    let(:user_guid) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }
    let(:isolation_segment) { IsolationSegmentModel.make }

    describe '#update' do
      let(:message) do
        SpaceUpdateIsolationSegmentMessage.new({ data: { guid: isolation_segment.guid } })
      end

      context ' when the org is entitled to the isolation segment' do
        let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

        before do
          assigner.assign(isolation_segment, [org])
        end

        it 'updates the isolation segment for the space' do
          expect(space.isolation_segment_guid).to eq(nil)

          space_update.update(space, org, message)
          space.reload

          expect(space.isolation_segment_guid).to eq(isolation_segment.guid)
        end

        it 'creates an audit event' do
          expect_any_instance_of(Repositories::SpaceEventRepository).to receive(:record_space_update).with(
            space,
            user_audit_info,
            { 'data' => { guid: isolation_segment.guid } }
          )

          space_update.update(space, org, message)
        end

        context 'when given a nil isolation segment' do
          let(:message) { SpaceUpdateIsolationSegmentMessage.new(data: nil) }

          before do
            space.update(isolation_segment_guid: isolation_segment.guid)
          end

          it 'unsets the isolation segment for the space' do
            expect(space.isolation_segment_guid).to eq(isolation_segment.guid)

            space_update.update(space, org, message)
            space.reload

            expect(space.isolation_segment_guid).to eq(nil)
          end
        end

        context 'when the space is invalid' do
          before do
            allow(space).to receive(:save).and_raise(Sequel::ValidationFailed.new('something'))
          end

          it 'raises an error' do
            expect { space_update.update(space, org, message) }.to raise_error(
              SpaceUpdateIsolationSegment::Error, /something/)
          end
        end
      end

      context 'when the org is NOT entitled to the isolation segment' do
        it 'raises an error' do
          expect { space_update.update(space, org, message) }.to raise_error(
            VCAP::CloudController::SpaceUpdateIsolationSegment::Error, /Unable to assign/)
        end
      end

      context 'when the given isolation segment does not exist' do
        let(:message) do
          SpaceUpdateIsolationSegmentMessage.new({ data: { guid: 'non-existant-guid' } })
        end

        it 'raises an error' do
          expect { space_update.update(space, org, message) }.to raise_error(
            VCAP::CloudController::SpaceUpdateIsolationSegment::Error, /Unable to assign/)
        end
      end
    end
  end
end
