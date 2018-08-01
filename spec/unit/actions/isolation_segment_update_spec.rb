require 'spec_helper'
require 'isolation_segment_update'

module VCAP::CloudController
  RSpec.describe IsolationSegmentUpdate do
    let!(:isolation_segment) { IsolationSegmentModel.make name: 'Old Name' }

    it 'updates the name of the isolation segment' do
      new_name = 'New Name'
      message = IsolationSegmentUpdateMessage.new name: new_name
      subject.update isolation_segment, message
      expect(isolation_segment.name).to eq(new_name)
    end

    it 'does not update the shared segment' do
      shared_segment = IsolationSegmentModel.first(guid: IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
      message = IsolationSegmentUpdateMessage.new
      expect {
        subject.update shared_segment, message
      }.to raise_error(CloudController::Errors::ApiError, /Cannot update the shared Isolation Segment/)
    end

    it 'does not update if the message does not request a name update' do
      message = IsolationSegmentUpdateMessage.new
      subject.update isolation_segment, message
      expect(isolation_segment.name).to eq('Old Name')
    end

    context 'when the isolation_segment is invalid' do
      before do
        allow_any_instance_of(IsolationSegmentModel).to receive(:save).and_raise(Sequel::ValidationFailed.new('booooooo'))
      end

      it 'raises an InvalidIsolationSegment error' do
        message = IsolationSegmentUpdateMessage.new
        expect {
          subject.update isolation_segment, message
        }.to raise_error(IsolationSegmentUpdate::InvalidIsolationSegment, 'booooooo')
      end
    end

    context 'when the isolation segment is assigned to an org' do
      let(:assigner) { IsolationSegmentAssign.new }
      let(:org) { Organization.make }

      before do
        assigner.assign(isolation_segment, [org])
      end

      it 'updates the name of the isolation segment' do
        new_name = 'New Name'
        message = IsolationSegmentUpdateMessage.new name: new_name
        subject.update isolation_segment, message
        expect(isolation_segment.name).to eq(new_name)
      end

      context 'and it is the org default' do
        before do
          org.update(default_isolation_segment_model: isolation_segment)
          org.reload
        end

        it 'updates the name of the isolation segment' do
          new_name = 'New Name'
          message = IsolationSegmentUpdateMessage.new name: new_name
          subject.update isolation_segment, message
          expect(isolation_segment.name).to eq(new_name)
        end

        context 'and there are spaces for that org' do
          let!(:space) { Space.make(organization: org) }

          it 'updates the name of the isolation segment' do
            new_name = 'New Name'
            message = IsolationSegmentUpdateMessage.new name: new_name
            subject.update isolation_segment, message
            expect(isolation_segment.name).to eq(new_name)
          end

          context 'and a space contains apps' do
            it 'fails' do
              AppModel.make(space: space)

              message = IsolationSegmentUpdateMessage.new
              expect {
                subject.update isolation_segment, message
              }.to raise_error(CloudController::Errors::ApiError, /Updating Isolation Segment with name /)
            end

            context 'and the space has a different assigned isolation segment' do
              let(:isolation_segment2) { IsolationSegmentModel.make }

              before do
                assigner.assign(isolation_segment2, [org])
                space.update(isolation_segment_guid: isolation_segment2.guid)

                AppModel.make(space: space)
              end

              it 'updates the name of the isolation segment' do
                new_name = 'New Name'
                message = IsolationSegmentUpdateMessage.new name: new_name
                subject.update isolation_segment, message
                expect(isolation_segment.name).to eq(new_name)
              end
            end
          end
        end
      end

      context 'and the segment is assigned to a space in the org' do
        let!(:space) { Space.make(organization: org, isolation_segment_guid: isolation_segment.guid) }

        it 'succeeds' do
          new_name = 'New Name'
          message = IsolationSegmentUpdateMessage.new name: new_name
          subject.update isolation_segment, message
          expect(isolation_segment.name).to eq(new_name)
        end

        context 'and the space contains apps' do
          before do
            AppModel.make(space: space)
          end

          it 'fails' do
            message = IsolationSegmentUpdateMessage.new
            expect {
              subject.update isolation_segment, message
            }.to raise_error(CloudController::Errors::ApiError, /Cannot update/)
          end
        end
      end
    end
  end
end
