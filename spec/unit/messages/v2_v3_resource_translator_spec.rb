require 'spec_helper'
require 'messages/v2_v3_resource_translator'

RSpec.describe VCAP::CloudController::V2V3ResourceTranslator do
  describe '#v2_fingerprints_body' do
    context 'when given v2 params' do
      let(:params) do
        [
          {
            sha1: '002d760bea1be268e27077412e11a320d0f164d3',
            size: 36,
            fn: '/path/to/first',
            mode: '123'
          },
          {
            sha1: 'a9993e364706816aba3e25717850c26c9cd0d89d',
            size: 1,
            fn: 'C:\\Program Files (x86)\\yep',
            mode: '644'
          }
        ]
      end

      it 'can transform the data back out to the v2 fingerprint format' do
        message = described_class.new(params)
        expect(message.v2_fingerprints_body).to eq([
          {
            sha1: '002d760bea1be268e27077412e11a320d0f164d3',
            size: 36,
            fn: '/path/to/first',
            mode: '123'
          },
          {
            sha1: 'a9993e364706816aba3e25717850c26c9cd0d89d',
            size: 1,
            fn: 'C:\\Program Files (x86)\\yep',
            mode: '644'
          }
        ])
      end
    end

    context 'when given v3 params' do
      let(:params) do
        [
          {
            checksum: { value: '002d760bea1be268e27077412e11a320d0f164d3' },
            size_in_bytes: 36,
            path: '/path/to/first',
            mode: '123'
          },
          {
            checksum: { value: 'a9993e364706816aba3e25717850c26c9cd0d89d' },
            size_in_bytes: 1,
            path: 'C:\\Program Files (x86)\\yep',
            mode: '644'
          }
        ]
      end

      it 'can transform the data back out to the v2 fingerprint format' do
        message = described_class.new(params)
        expect(message.v2_fingerprints_body).to eq([
          {
            sha1: '002d760bea1be268e27077412e11a320d0f164d3',
            size: 36,
            fn: '/path/to/first',
            mode: '123'
          },
          {
            sha1: 'a9993e364706816aba3e25717850c26c9cd0d89d',
            size: 1,
            fn: 'C:\\Program Files (x86)\\yep',
            mode: '644'
          }
        ])
      end
    end
  end
end
