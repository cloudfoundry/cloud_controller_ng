# coding: utf-8

require 'spec_helper'

module VCAP::Errors
  describe ApiError do
    def create_details(message)
      double(Details,
             name: message,
             response_code: 400,
             code: 12345)
    end

    let(:locale) { nil }
    let(:translation_key) { "TranslatedMessage" }

    let(:args) { {arg1: 'foo', arg2: 'bar'} }

    let(:messageDetails) { create_details(translation_key) }
    let(:translations) { Dir[File.expand_path("../../../../../fixtures/i18n/*.yml", __FILE__)] }


    let(:api_error) { ApiError.new_from_details(translation_key, args) }

    before do
      I18n.enforce_available_locales = true # this will be the default in a future version, so test that we cope with it
      ApiError.setup_i18n(translations, "en_US")

      expect(I18n.load_path).to have(2).items
      expect(I18n.default_locale).to eq(:en_US)

      allow(Details).to receive("new").with(translation_key.split(".").first).and_return(messageDetails)

      I18n.locale = locale
    end

    after do
      I18n.locale = "en"
      I18n.load_path = []
      I18n.backend.reload!
    end

    describe "new_from_details" do
      it "returns an ApiError" do
        expect(api_error).to be_a(ApiError)
      end

      context "if it doesn't recognise the error from v2.yml" do
        let(:translated_message) { "InvalidErrorMessageKey"}

        before do
          allow(Details).to receive(:new).and_call_original
        end

        it "explodes" do
          expect { api_error }.to raise_error
        end
      end
    end

    describe "message" do
      it "translates the message based on the locale" do
        I18n.locale = :en_US
        expect(api_error.message).to eq("This is a translated message of foo bar.")
        I18n.locale = :zh_CN
        expect(api_error.message).to eq("这是一条被翻译的信息：foo bar。")
      end

      context "when args is an array" do
        let(:args) { [:foo, 1] }
        let(:translation_key) { "MessageWithStringArg" }

        it "joins the elements as a string" do
          expect(api_error.message).to eq("Message with string: foo, 1")
        end
      end

      context "when the message is not translated in the target locale" do
        let(:translation_key) { "OnlyInDefaultLocale" }
        let(:locale) { :zh_CN }

        it "uses the default locale message" do
          expect(api_error.message).to eq("This is a translated message of foo bar only in default locale")
        end
      end

      context "when the locale is not recognized" do
        let(:locale) { :unknown_locale }

        it "uses the default locale message" do
          expect(api_error.message).to eq("This is a translated message of foo bar.")
        end
      end

      context "when the translation is missing" do
        let(:translation_key) { "bogus_key" }

        it "raises an error when the translation is missing" do
          expect { api_error.message }.to raise_error(I18n::MissingTranslationData)
        end
      end

      context "when error has nested translations" do
        context "when the nested key is not specified" do
          let(:translation_key) { "MessageWithNestedTranslations" }

          it "it uses the nested key of 'default'" do
            expect(api_error.message).to eq("Default message: foo")
          end
        end

        context "when the nested key is specified" do
          let(:translation_key) { "MessageWithNestedTranslations.nested_message_1" }

          it "uses the translation for the nested key" do
            expect(api_error.message).to eq("Nested message 1: foo")
          end

          context "when the message is not translated in the target locale" do
            let(:locale) { :zh_CN }

            it "uses the default locale message" do
              expect(api_error.message).to eq("Nested message 1: foo")
            end
          end
        end
      end
    end

    describe "details" do
      it "exposes the code" do
        expect(api_error.code).to eq(12345)
      end

      it "exposes the http code" do
        expect(api_error.response_code).to eq(400)
      end

      it "exposes the name" do
        expect(api_error.name).to eq(translation_key)
      end
    end
  end
end
