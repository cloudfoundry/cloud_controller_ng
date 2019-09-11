require 'spec_helper'

RSpec.describe ErrorPresenter do
  subject(:presenter) { ErrorPresenter.new(error, test_mode, error_hasher) }

  class ResponsiveStandardError < StandardError
    # With verify-partial-double we can't test dynamic method introspection
    # So any test that needs to test error#response_code will have to use this class.
    def response_code
      raise 'ResponsiveStandardError.response_code: not implemented'
    end
  end

  let(:error) { ResponsiveStandardError.new }
  let(:sanitized_error_hash) { { 'fake' => 'sane' } }
  let(:unsanitized_error_hash) { { 'fake' => 'insane' } }
  let(:error_hasher) { double(V2ErrorHasher, unsanitized_hash: unsanitized_error_hash, sanitized_hash: sanitized_error_hash, api_error?: false) }
  let(:test_mode) { false }

  describe '#client_error?' do
    context 'when the response code is 4xx' do
      before do
        allow(error).to receive(:response_code).and_return(403)
      end

      it { is_expected.to be_a_client_error }
    end

    context 'when the response code is not 4xx' do
      before do
        allow(error).to receive(:response_code).and_return(500)
      end

      it { is_expected.not_to be_a_client_error }
    end
  end

  describe '#log_message' do
    let(:error) { StandardError.new }
    it 'logs the response code and unsanitized error hash' do
      expect(presenter.log_message).to eq('Request failed: 500: {"fake"=>"insane"}')
    end
  end

  describe '#api_error?' do
    it 'delegates to the error_hasher' do
      expect(error_hasher).to receive(:api_error?).and_return('foo')
      expect(presenter.api_error?).to eq('foo')
    end
  end

  describe '#reponse_code' do
    context 'when the error knows its response code' do
      before do
        allow(error).to receive(:response_code).and_return(403)
      end

      it "returns the error's response code" do
        expect(presenter.response_code).to eq(error.response_code)
      end
    end

    context 'when the error does not have an associated response code' do
      let(:error) { StandardError.new }
      it 'returns 500' do
        expect(presenter.response_code).to eq(500)
      end
    end
  end

  describe '#to_hash' do
    context 'when in test mode' do
      let(:test_mode) { true }

      it 'returns the unsanitized hash representation of the error' do
        allow(error).to receive(:response_code).and_return(422)
        expect(presenter.to_hash).to eq('fake' => 'insane')
        expect(error_hasher).to have_received(:unsanitized_hash)
      end

      context 'when the response code is 500' do
        before do
          allow(error).to receive(:response_code).and_return(500)
        end

        it 'raises the error' do
          expect {
            presenter.to_hash
          }.to raise_error(ResponsiveStandardError)
        end
      end

      context 'when the error does not respond to response_code' do
        class CustomError < StandardError; end
        let(:error) { CustomError.new }

        it 'raises the error' do
          expect {
            presenter.to_hash
          }.to raise_error(CustomError)
        end
      end
    end

    context 'when not in test mode' do
      let(:test_mode) { false }

      it 'returns the sanitized hash representation of the error' do
        expect(presenter.to_hash).to eq('fake' => 'sane')
        expect(error_hasher).to have_received(:sanitized_hash)
      end
    end
  end
end
