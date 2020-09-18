require 'lightweight_spec_helper'
require 'cloud_controller/errors/v3/api_error'

module CloudController::Errors::V3
  RSpec.describe ApiError do
    def create_details(message)
      double(Details,
             name: message,
             response_code: 400,
             code: 12345,
             message_format: 'Before %s %s after.')
    end

    let(:messageServiceInvalid) { 'ServiceInvalid' }
    let(:args) { ['foo', 'bar'] }

    let(:messageServiceInvalidDetails) { create_details(messageServiceInvalid) }

    before do
      allow(Details).to receive('new').with(messageServiceInvalid).and_return(messageServiceInvalidDetails)
    end

    context '.new_from_details' do
      subject(:api_error) { ApiError.new_from_details(messageServiceInvalid, *args) }

      it 'returns an ApiError' do
        expect(api_error).to be_a(ApiError)
      end

      it 'should be an exception' do
        expect(api_error).to be_a(Exception)
      end

      context "if it doesn't recognise the error from v3.yml" do
        let(:messageServiceInvalid) { 'NotAuthenticated' }

        before do
          allow(Details).to receive(:new).and_call_original
        end

        it 'explodes' do
          expect { api_error }.to raise_error(KeyError, /key not found/)
        end
      end
    end

    describe 'message' do
      subject(:api_error) { ApiError.new_from_details(messageServiceInvalid, *args) }

      it 'should interpolate the message' do
        expect(api_error.message).to eq('Before foo bar after.')
      end

      context 'when initializing an api_error without new_from_details' do
        let(:api_error) { ApiError.new }

        it 'should not explode' do
          expect {
            api_error.message
          }.not_to raise_error
        end
      end

      context 'when error_prefix is set' do
        before do
          api_error.error_prefix = 'the prefix: '
        end

        it 'returns the message prefixed with the prefix' do
          expect(api_error.message).to eq('the prefix: Before foo bar after.')
        end
      end
    end

    context 'with details' do
      subject(:api_error) { ApiError.new }

      before do
        api_error.details = messageServiceInvalidDetails
      end

      it 'exposes the code' do
        expect(api_error.code).to eq(12345)
      end

      it 'exposes the http code' do
        expect(api_error.response_code).to eq(400)
      end

      it 'exposes the name' do
        expect(api_error.name).to eq('ServiceInvalid')
      end
    end
  end
end
