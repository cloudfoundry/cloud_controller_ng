require 'lightweight_spec_helper'
require 'cloud_controller/errors/api_error'

module CloudController::Errors
  RSpec.describe ApiError do
    def create_details(message)
      double(Details,
             name: message,
             response_code: 400,
             code: 12_345,
             message_format: 'Before %s %s after.')
    end

    let(:messageServiceInvalid) { 'ServiceInvalid' }
    let(:args) { %w[foo bar] }

    let(:messageServiceInvalidDetails) { create_details(messageServiceInvalid) }

    before do
      allow(Details).to receive('new').with(messageServiceInvalid).and_return(messageServiceInvalidDetails)
    end

    describe '.new_from_details' do
      subject(:api_error) { ApiError.new_from_details(messageServiceInvalid, *args) }

      it 'returns an ApiError' do
        expect(api_error).to be_a(ApiError)
      end

      it 'is an exception' do
        expect(api_error).to be_a(Exception)
      end

      context "if it doesn't recognise the error from v2.yml" do
        let(:messageServiceInvalid) { "What is this?  I don't know?!!" }

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

      it 'interpolates the message' do
        expect(api_error.message).to eq('Before foo bar after.')
      end

      context 'when initializing an api_error without new_from_details' do
        let(:api_error) { ApiError.new }

        it 'does not explode' do
          expect do
            api_error.message
          end.not_to raise_error
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
        expect(api_error.code).to eq(12_345)
      end

      it 'exposes the http code' do
        expect(api_error.response_code).to eq(400)
      end

      it 'can be set to a different http code' do
        api_error.with_response_code(422)
        expect(api_error.response_code).to eq(422)
      end

      it 'exposes the name' do
        expect(api_error.name).to eq('ServiceInvalid')
      end
    end
  end
end
