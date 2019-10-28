require 'spec_helper'
require 'messages/validators/url_validator'

module VCAP::CloudController::Validators
  RSpec.describe 'UrlValidator' do
    let(:class_with_url) do
      Class.new do
        include ActiveModel::Model
        validates_with UrlValidator

        attr_accessor :url
      end
    end

    subject(:message) do
      class_with_url.new(url: url)
    end

    context 'when the scheme is http' do
      let(:url) { 'http://the-best-broker.url' }

      it 'is valid' do
        expect(message).to be_valid
      end
    end

    context 'when the scheme is https' do
      let(:url) { 'https://the-best-broker.url' }

      it 'is valid' do
        expect(message).to be_valid
      end
    end

    context 'when url is not valid' do
      let(:url) { 'lol.com' }

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:url)).to include("'lol.com' must be a valid url")
      end
    end

    context 'when url has wrong scheme' do
      let(:url) { 'ftp://the-best-broker.url' }

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:url)).to include("'ftp://the-best-broker.url' must be a valid url")
      end
    end

    context 'when url contains a basic auth user' do
      let(:url) { 'http://username@lol.com' }

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:url)).to include('must not contain authentication')
      end
    end

    context 'when url contains a basic auth password' do
      let(:url) { 'http://username:password@lol.com' }

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:url)).to include('must not contain authentication')
      end
    end
  end
end
