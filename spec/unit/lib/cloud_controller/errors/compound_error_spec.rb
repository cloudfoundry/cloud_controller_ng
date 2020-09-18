require 'lightweight_spec_helper'
require 'cloud_controller/errors/compound_error'
require 'cloud_controller/errors/api_error'

module CloudController::Errors
  RSpec.describe CompoundError do
    describe '#underlying_errors' do
      it 'returns the provided list of API errors' do
        errors = [
          ApiError.new_from_details('StagingError', 'message1'),
          ApiError.new_from_details('UnprocessableEntity', 'message2'),
        ]
        compound_error = CompoundError.new(errors)
        expect(compound_error.underlying_errors).to eq errors
      end
    end

    describe '#response_code' do
      it 'returns the response code of the first error' do
        errors = [
          ApiError.new_from_details('StagingError', 'message1'),
          ApiError.new_from_details('UnprocessableEntity', 'message2'),
        ]
        compound_error = CompoundError.new(errors)
        expect(compound_error.response_code).to eq 400

        compound_error = CompoundError.new(errors.reverse)
        expect(compound_error.response_code).to eq 422
      end
    end
  end
end
