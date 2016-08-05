require 'spec_helper'

module CloudController
  RSpec.describe UrlSecretObfuscator do
    describe '#obfuscate' do
      context 'when the username and password are in the url' do
        let(:url) { 'https://amelialovescats:meowmeow@github.com/my-stuff&q=heart' }

        it 'obfuscates the username and password' do
          obfuscated_url = described_class.obfuscate(url)

          expect(obfuscated_url).to eq 'https://***:***@github.com/my-stuff&q=heart'
        end
      end

      context 'when there is no password' do
        let(:url) { 'https://amelialovescats@github.com/my-stuff&q=heart' }

        it 'obfuscates the username and password' do
          obfuscated_url = described_class.obfuscate(url)

          expect(obfuscated_url).to eq 'https://***:***@github.com/my-stuff&q=heart'
        end
      end

      context 'when the url has neither username nor credentials' do
        let(:url) { 'https://github.com/my-stuff&q=heart' }

        it 'obfuscates nothing' do
          obfuscated_url = described_class.obfuscate(url)

          expect(obfuscated_url).to eq 'https://github.com/my-stuff&q=heart'
        end
      end
    end
  end
end
