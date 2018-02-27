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
  end
end
