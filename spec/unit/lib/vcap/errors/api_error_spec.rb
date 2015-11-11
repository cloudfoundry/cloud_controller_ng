# coding: utf-8

require 'spec_helper'

module VCAP::Errors
  describe ApiError do
    def create_details(message)
      double(Details,
             name: message,
             response_code: 400,
             code: 12345,
             message_format: 'Before %s %s after.')
    end

    let(:messageServiceInvalid) { 'ServiceInvalid' }
    let(:messagePartialTranslated) { 'MessagePartialTranslated' }
    let(:messageNotTranslated) { 'MessageNotTranslated' }
    let(:args) { ['foo', 'bar'] }

    let(:messageServiceInvalidDetails) { create_details(messageServiceInvalid) }
    let(:messagePartialTranslatedDetails) { create_details(messagePartialTranslated) }
    let(:messageNotTranslatedDetails) { create_details(messageNotTranslated) }

    let(:translations) { Dir[File.expand_path('../../../../../fixtures/i18n/*.yml', __FILE__)] }

    before do
      @original_load_paths = I18n.load_path.dup
      I18n.fallbacks = nil
      I18n.enforce_available_locales = true # this will be the default in a future version, so test that we cope with it
      ApiError.setup_i18n(translations, 'en_US')

      expect(I18n.default_locale).to eq(:en_US)

      allow(Details).to receive('new').with(messageServiceInvalid).and_return(messageServiceInvalidDetails)
      allow(Details).to receive('new').with(messagePartialTranslated).and_return(messagePartialTranslatedDetails)
      allow(Details).to receive('new').with(messageNotTranslated).and_return(messageNotTranslatedDetails)
    end

    after do
      I18n.locale = 'en'
      I18n.load_path = @original_load_paths
      I18n.backend.reload!
    end

    context '.new_from_details' do
      subject(:api_error) { ApiError.new_from_details(messageServiceInvalid, *args) }

      it 'returns an ApiError' do
        expect(api_error).to be_a(ApiError)
      end

      it 'should be an exception' do
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

    context 'get error message' do
      subject(:api_error) { ApiError.new_from_details(messageServiceInvalid, *args) }
      subject(:api_error_with_partial_translation) { ApiError.new_from_details(messagePartialTranslated, *args) }
      subject(:api_error_with_translation_missing)  { ApiError.new_from_details(messageNotTranslated, *args) }

      it 'should translate the message based on the locale' do
        I18n.locale = :en_US
        expect(api_error.message).to eq('This is a translated message of foo bar.')
        I18n.locale = :zh_CN
        expect(api_error.message).to eq('这是一条被翻译的信息：foo bar。')
      end

      it 'should use the default locale message when the message is not translated in target locale' do
        I18n.locale = :zh_CN
        expect(api_error_with_partial_translation.message).to eq('This is a translated message of foo bar only in default locale')
      end

      it 'should use the default locale message when the locale is not recognized' do
        I18n.locale = :unknown_locale
        expect(api_error.message).to eq('This is a translated message of foo bar.')
      end

      it 'should use the original message when the translation is missing' do
        I18n.locale = :en_US
        expect(api_error_with_translation_missing.message).to eq('Before foo bar after.')
      end

      context 'when initializing an api_error without new_from_details' do
        let(:api_error) { ApiError.new }

        it 'should not explode' do
          expect {
            api_error.message
          }.not_to raise_error
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
