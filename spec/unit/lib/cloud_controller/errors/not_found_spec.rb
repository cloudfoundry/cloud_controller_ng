require 'spec_helper'

module CloudController::Errors
  RSpec.describe NotFound do
    context 'when a wrapped error is provided' do
      let(:message) { 'uh oh' }
      let(:exception_details) { create_details(message) }
      let(:error) { CloudController::Errors::NotFound.new_from_details(message) }

      before do
        allow(Details).to receive('new').with(message).and_return(exception_details)
      end

      it 'returns the error name' do
        expect(error.name).to eq('uh oh')
      end

      it 'returns the response code' do
        expect(error.response_code).to eq(222)
      end

      it 'returns the wrapped error code' do
        expect(error.code).to eq(12345)
      end
    end

    def create_details(message)
      double(Details,
             name: message,
             response_code: 222,
             code: 12345,
             message_format: 'Before %s %s after.')
    end
  end
end
