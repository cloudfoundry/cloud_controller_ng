require 'spec_helper'
require 'messages/validators'

module VCAP::CloudController::Validators
  RSpec.describe SimpleTimestampValidator do
    let(:validator) { SimpleTimestampValidator.new(attributes: [:timestamp_field]) }
    let(:record) { double('record', errors:) }
    let(:errors) { double('errors') }

    describe '#validate_each' do
      context 'when value is nil' do
        it 'does not add any errors' do
          expect(errors).not_to receive(:add)
          validator.validate_each(record, :timestamp_field, nil)
        end
      end

      context 'when value is a valid ISO 8601 timestamp' do
        it 'does not add any errors' do
          expect(errors).not_to receive(:add)
          validator.validate_each(record, :timestamp_field, '2023-01-01T12:00:00Z')
        end
      end

      context 'when value is an invalid timestamp format' do
        it 'adds an error for non-ISO 8601 format' do
          expect(errors).to receive(:add).with(:timestamp_field, message: "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
          validator.validate_each(record, :timestamp_field, 'not-a-timestamp')
        end

        it 'adds an error for missing Z suffix' do
          expect(errors).to receive(:add).with(:timestamp_field, message: "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
          validator.validate_each(record, :timestamp_field, '2023-01-01T12:00:00')
        end

        it 'adds an error for wrong date format' do
          expect(errors).to receive(:add).with(:timestamp_field, message: "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
          validator.validate_each(record, :timestamp_field, '01-01-2023T12:00:00Z')
        end

        it 'adds an error for missing time part' do
          expect(errors).to receive(:add).with(:timestamp_field, message: "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
          validator.validate_each(record, :timestamp_field, '2023-01-01')
        end

        it 'adds an error for invalid time format' do
          expect(errors).to receive(:add).with(:timestamp_field, message: "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
          validator.validate_each(record, :timestamp_field, '2023-01-01T1:00:00Z')
        end

        it 'adds an error for extra characters' do
          expect(errors).to receive(:add).with(:timestamp_field, message: "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
          validator.validate_each(record, :timestamp_field, '2023-01-01T12:00:00Z extra')
        end

        it 'adds an error for timezone offset instead of Z' do
          expect(errors).to receive(:add).with(:timestamp_field, message: "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
          validator.validate_each(record, :timestamp_field, '2023-01-01T12:00:00+00:00')
        end
      end

      context 'when value is a number' do
        it 'adds an error' do
          expect(errors).to receive(:add).with(:timestamp_field, message: "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
          validator.validate_each(record, :timestamp_field, 123_456_789)
        end
      end

      context 'when value is an empty string' do
        it 'adds an error' do
          expect(errors).to receive(:add).with(:timestamp_field, message: "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
          validator.validate_each(record, :timestamp_field, '')
        end
      end
    end
  end
end
