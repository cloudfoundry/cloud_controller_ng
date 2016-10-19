require 'spec_helper'
require 'isolation_segment_update'

module VCAP::CloudController
  RSpec.describe IsolationSegmentUpdate do
    let(:isolation_segment) { IsolationSegmentModel.make name: 'Old Name' }

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
  end
end
