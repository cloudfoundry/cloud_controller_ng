require 'spec_helper'
require 'isolation_segment_update'

module VCAP::CloudController
  RSpec.describe IsolationSegmentUpdate do
    let!(:isolation_segment) { IsolationSegmentModel.make name: 'Old Name' }

    it 'updates the name of the isolation segment' do
      new_name = 'New Name'
      message = IsolationSegmentUpdateMessage.new(name: new_name)
      subject.update(isolation_segment, message)
      expect(isolation_segment.name).to eq(new_name)
    end

    it 'does not update the shared segment' do
      shared_segment = IsolationSegmentModel.first(guid: IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
      message = IsolationSegmentUpdateMessage.new({})
      expect do
        subject.update(shared_segment, message)
      end.to raise_error(CloudController::Errors::ApiError, /Cannot update the shared Isolation Segment/)
    end

    it 'does not update if the message does not request a name update' do
      message = IsolationSegmentUpdateMessage.new({})
      subject.update(isolation_segment, message)
      expect(isolation_segment.name).to eq('Old Name')
    end

    context 'when there is metadata' do
      let!(:label) { IsolationSegmentLabelModel.make(resource_guid: isolation_segment.guid, key_name: 'freaky', value: 'tuesday') }
      let!(:annotation) { IsolationSegmentAnnotationModel.make(resource_guid: isolation_segment.guid, key_name: 'hello', value: 'general kenobi') }

      it 'updates the metadata' do
        message = VCAP::CloudController::IsolationSegmentUpdateMessage.new({
                                                                             metadata: {
                                                                               labels: {
                                                                                 freaky: 'wednesday'
                                                                               },
                                                                               annotations: {
                                                                                 hello: 'there'
                                                                               }
                                                                             }
                                                                           })

        subject.update(isolation_segment, message)

        expect(isolation_segment.labels.first.key_name).to eq 'freaky'
        expect(isolation_segment.labels.first.value).to eq 'wednesday'
        expect(isolation_segment.annotations.first.key_name).to eq 'hello'
        expect(isolation_segment.annotations.first.value).to eq 'there'
      end

      it 'removes the metadata' do
        message = VCAP::CloudController::IsolationSegmentUpdateMessage.new({
                                                                             metadata: {
                                                                               labels: {
                                                                                 freaky: nil
                                                                               },
                                                                               annotations: {
                                                                                 hello: nil
                                                                               }
                                                                             }
                                                                           })

        subject.update(isolation_segment, message)

        expect(isolation_segment.labels).to be_empty
        expect(isolation_segment.annotations).to be_empty
      end

      it 'adds metadata' do
        message = VCAP::CloudController::IsolationSegmentUpdateMessage.new({
                                                                             metadata: {
                                                                               annotations: {
                                                                                 howdy: 'yooo'
                                                                               }
                                                                             }
                                                                           })

        subject.update(isolation_segment, message)

        expect(isolation_segment.annotations).to have(2).items
      end
    end

    context 'when the isolation_segment is invalid' do
      before do
        allow_any_instance_of(IsolationSegmentModel).to receive(:save).and_raise(Sequel::ValidationFailed.new('booooooo'))
      end

      it 'raises an InvalidIsolationSegment error' do
        message = IsolationSegmentUpdateMessage.new({})
        expect do
          subject.update(isolation_segment, message)
        end.to raise_error(IsolationSegmentUpdate::InvalidIsolationSegment, 'booooooo')
      end
    end

    context 'when the isolation segment is set as the org default' do
      let(:assigner) { IsolationSegmentAssign.new }
      let(:org) { Organization.make }

      before do
        assigner.assign(isolation_segment, [org])
        org.update(default_isolation_segment_model: isolation_segment)
        org.reload
      end

      it 'does not allow updating the iso seg name' do
        message = IsolationSegmentUpdateMessage.new(name: 'New Name')
        expect { subject.update(isolation_segment, message) }.to raise_error(
          CloudController::Errors::ApiError,
          /Cannot update Isolation Segments that are assigned as the default for an Organization or Space/
        )
        expect(isolation_segment.name).to eq('Old Name')
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
        message = IsolationSegmentUpdateMessage.new(name: new_name)
        subject.update(isolation_segment, message)
        expect(isolation_segment.name).to eq(new_name)
      end

      context 'and the segment is assigned to a space in the org' do
        let!(:space) { Space.make(organization: org, isolation_segment_guid: isolation_segment.guid) }

        it 'does not allow updating the iso seg name' do
          message = IsolationSegmentUpdateMessage.new(name: 'New Name')
          expect { subject.update(isolation_segment, message) }.to raise_error(
            CloudController::Errors::ApiError,
            /Cannot update Isolation Segments that are assigned as the default for an Organization or Space/
          )
          expect(isolation_segment.name).to eq('Old Name')
        end
      end
    end
  end
end
