require 'spec_helper'

module VCAP::CloudController
  RSpec.describe FrontController do
    let(:fake_logger) { double(Steno::Logger, info: nil) }

    before :all do
      FrontController.get '/test_front_endpoint' do
        'test'
      end

      FrontController.options '/test_front_endpoint' do
        status 201
        'options'
      end
    end

    describe 'setting the locale' do
      before do
        @original_default_locale = I18n.default_locale
        @original_locale         = I18n.locale

        I18n.default_locale = :metropolis
        I18n.locale         = :metropolis
      end

      after do
        I18n.default_locale = @original_default_locale
        I18n.locale         = @original_locale
      end

      context 'When the Accept-Language header is set' do
        it 'sets the locale based on the Accept-Language header' do
          get '/test_front_endpoint', '', { 'HTTP_ACCEPT_LANGUAGE' => 'gotham_City' }
          expect(I18n.locale).to eq(:gotham_City)
        end
      end

      context 'when the Accept-Language header is not set' do
        it 'maintains the default locale' do
          get '/test_front_endpoint', '', {}
          expect(I18n.locale).to eq(:metropolis)
        end
      end
    end
  end
end
