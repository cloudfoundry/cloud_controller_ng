require 'spec_helper'
require 'messages/resource_match_create_message'

RSpec.describe VCAP::CloudController::ResourceMatchCreateMessage do
  describe 'creation with v3' do
    let(:valid_v3_params) do
      {
        resources: [
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
      }
    end

    it 'is valid if using the valid parameters' do
      expect(described_class.new(valid_v3_params)).to be_valid
    end

    it 'can marshal data back out to the v2 fingerprint format' do
      message = described_class.new(valid_v3_params)
      expect(message.v2_fingerprints_body.string).to eq([
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
      ].to_json)
    end

    describe 'validations' do
      subject { described_class.new(params) }

      context 'when the v3 resources array is too long' do
        let(:params) do
          {
            resources: Array.new(5001) do
              {
                checksum: { value: '002d760bea1be268e27077412e11a320d0f164d3' },
                size_in_bytes: 36
              }
            end
          }
        end

        it 'has the correct error message' do
          expect(subject).to be_invalid
          expect(subject.errors[:resources]).to include('array can have at most 5000 resources')
        end
      end

      context 'when the v3 resources array is empty' do
        let(:params) do
          {
            resources: []
          }
        end

        it 'has the correct error message' do
          expect(subject).to be_invalid
          expect(subject.errors[:resources]).to include('must have at least 1 resource')
        end
      end

      context 'when the v3 checksum parameter is not a JSON object' do
        let(:params) do
          {
            resources: [
              {
                checksum: true,
                size_in_bytes: 36
              }
            ]
          }
        end

        it 'has the correct error message' do
          expect(subject).to be_invalid
          expect(subject.errors[:resources]).to include('array contains at least one resource with a non-object checksum')
        end
      end

      context 'when the v3 checksum value is not a string' do
        let(:params) do
          {
            resources: [
              {
                checksum: { value: false },
                size_in_bytes: 36
              }
            ]
          }
        end

        it 'has the correct error message' do
          expect(subject).to be_invalid
          expect(subject.errors[:resources]).to include('array contains at least one resource with a non-string checksum value')
        end
      end

      context 'when the v3 checksum value is not a valid sha1' do
        let(:params) do
          {
            resources: [
              {
                checksum: { value: 'not-a-valid-sha' },
                size_in_bytes: 36
              }
            ]
          }
        end

        it 'has the correct error message' do
          expect(subject).to be_invalid
          expect(subject.errors[:resources]).to include('array contains at least one resource with a non-SHA1 checksum value')
        end
      end

      context 'when the v3 resource size is not an integer' do
        [true, 'x', 5.1, { size: 4 }].each do |size|
          it "has the correct error message when size is #{size}" do
            message = described_class.new({
              resources: [
                {
                  checksum: { value: '002d760bea1be268e27077412e11a320d0f164d3' },
                  size_in_bytes: size
                }
              ]
            })

            expect(message).to be_invalid
            expect(message.errors[:resources]).to include('array contains at least one resource with a non-integer size_in_bytes')
          end
        end
      end

      context 'when the v3 resource size is negative' do
        it 'is invalid' do
          message = described_class.new({
            resources: [
              {
                checksum: { value: '002d760bea1be268e27077412e11a320d0f164d3' },
                size_in_bytes: -1
              }
            ]
          })

          expect(message).to be_invalid
          expect(message.errors[:resources]).to include('array contains at least one resource with a negative size_in_bytes')
        end
      end

      context 'when there are multiple validation violations' do
        let(:params) do
          {
            resources: [
              {
                checksum: { value: 'not-a-valid-sha' },
                size_in_bytes: 36
              },
              {
                checksum: { value: 'not-a-valid-sha' },
                size_in_bytes: 36
              }
            ]
          }
        end

        it 'prints only a single error message for that violation' do
          expect(subject).to be_invalid
          expect(subject.errors[:resources]).to include('array contains at least one resource with a non-SHA1 checksum value')
          expect(subject.errors[:resources]).to have(1).items
        end
      end
    end
  end
end
