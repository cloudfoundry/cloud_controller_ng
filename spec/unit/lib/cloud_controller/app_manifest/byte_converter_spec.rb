require 'spec_helper'
require 'cloud_controller/app_manifest/byte_converter'

module VCAP::CloudController
  RSpec.describe ByteConverter do
    subject { ByteConverter.new }

    describe '#convert_to_mb' do
      context 'when given nil' do
        let(:byte_value) { nil }

        it 'returns nil' do
          expect(subject.convert_to_mb(byte_value)).to be_nil
        end
      end

      context 'when missing units' do
        context 'when given an integer' do
          let(:byte_value) { 200 }

          it 'raises a ByteConverter::InvalidUnitsError' do
            expect {
              subject.convert_to_mb(byte_value)
            }.to raise_error(ByteConverter::InvalidUnitsError)
          end
        end

        context 'when given an float' do
          let(:byte_value) { 200.5 }

          it 'raises a ByteConverter::InvalidUnitsError' do
            expect {
              subject.convert_to_mb(byte_value)
            }.to raise_error(ByteConverter::InvalidUnitsError)
          end
        end

        context 'when given an string' do
          let(:byte_value) { '200' }

          it 'raises a ByteConverter::InvalidUnitsError' do
            expect {
              subject.convert_to_mb(byte_value)
            }.to raise_error(ByteConverter::InvalidUnitsError)
          end
        end
      end

      context 'when value includes units' do
        context 'when the unit is invalid' do
          let(:byte_value) { '100INVALID' }

          it 'raises a ByteConverter::InvalidUnitsError' do
            expect {
              subject.convert_to_mb(byte_value)
            }.to raise_error(ByteConverter::InvalidUnitsError)
          end
        end

        context 'when the amount of MB requested is less than 1' do
          let(:byte_value) { '100B' }

          it 'rounds down to 0 MB' do
            expect(subject.convert_to_mb(byte_value)).to eq(0)
          end
        end

        context 'when specifying a fractional amount of MB' do
          let(:byte_value_close_to_ceiling) { '2047KB' }
          let(:byte_value_close_to_floor) { '1025KB' }

          it 'rounds down to the nearest MB' do
            expect(subject.convert_to_mb(byte_value_close_to_ceiling)).to eq(1)
            expect(subject.convert_to_mb(byte_value_close_to_floor)).to eq(1)
          end
        end

        context 'when given a string with an "integer" amount of bytes' do
          context 'when the unit is B' do
            let(:byte_value) { '1048576B' }

            it 'returns the the converted amount in MB' do
              expect(subject.convert_to_mb(byte_value)).to eq(1)
            end
          end

          context 'when the unit is K' do
            let(:byte_value) { '2048K' }

            it 'returns the the converted amount in MB' do
              expect(subject.convert_to_mb(byte_value)).to eq(2)
            end
          end

          context 'when the unit is MB' do
            let(:byte_value) { '200MB' }

            it 'returns the the converted amount in MB' do
              expect(subject.convert_to_mb(byte_value)).to eq(200)
            end
          end

          context 'when the unit is GB' do
            let(:byte_value) { '20GB' }

            it 'returns the the converted amount in MB' do
              expect(subject.convert_to_mb(byte_value)).to eq(20480)
            end
          end

          context 'when the unit is TB' do
            let(:byte_value) { '1TB' }

            it 'returns the the converted amount in MB' do
              expect(subject.convert_to_mb(byte_value)).to eq(1048576)
            end
          end
        end

        context 'when given an float' do
          let(:byte_value) { '20.1GB' }

          it 'returns the the converted amount in MB rounded down to the nearest MB' do
            expect(subject.convert_to_mb(byte_value)).to eq(20582)
          end
        end
      end
    end

    describe '#convert_to_b' do
      context 'when given 1M' do
        let(:byte_value) { '1M' }

        it 'returns the value in bytes' do
          expect(subject.convert_to_b(byte_value)).to eq(1_048_576)
        end
      end
    end

    describe '#human_readable_byte_value' do
      context 'when given nil' do
        let(:byte_value) { nil }

        it 'returns nil' do
          expect(subject.human_readable_byte_value(byte_value)).to be_nil
        end
      end

      context 'when given 1M in bytes' do
        let(:byte_value) { 1_048_576 }

        it 'returns the human readable value' do
          expect(subject.human_readable_byte_value(byte_value)).to eq('1M')
        end
      end

      context 'when given 1G in bytes' do
        let(:byte_value) { 1_073_741_824 }

        it 'returns the human readable value' do
          expect(subject.human_readable_byte_value(byte_value)).to eq('1G')
        end
      end

      context 'when given 1.1M in bytes' do
        let(:byte_value) { 1_153_434 }

        it 'returns the human readable value in bytes to avoid losing precision' do
          expect(subject.human_readable_byte_value(byte_value)).to eq('1153434B')
        end
      end

      context 'when given 1M + 1K' do
        let(:byte_value) { 1049600 }

        it 'returns the human readable value in kilobytes to avoid losing precision' do
          expect(subject.human_readable_byte_value(byte_value)).to eq('1025K')
        end
      end

      context 'when given a string' do
        let(:byte_value) { 'not-a-number' }

        it 'raises an error' do
          expect {
            subject.human_readable_byte_value(byte_value)
          }.to raise_error(ByteConverter::InvalidBytesError)
        end
      end

      context 'when given a float' do
        let(:byte_value) { 1.1 }

        it 'raises an error' do
          expect {
            subject.human_readable_byte_value(byte_value)
          }.to raise_error(ByteConverter::InvalidBytesError)
        end
      end

    end
  end
end
