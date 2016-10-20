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
  end
end
