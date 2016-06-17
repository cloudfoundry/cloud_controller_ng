require 'spec_helper'

module CloudController::Errors
  RSpec.describe Details do
    describe '.new(name)' do
      let(:name) { 'DomainInvalid' }

      subject(:details) do
        Details.new(name)
      end

      it 'knows the error name' do
        expect(details.name).to eq('DomainInvalid')
      end

      it 'knows the error http_code' do
        expect(details.response_code).to eq(400)
      end

      it 'knows code' do
        expect(details.code).to eq(130001)
      end

      it 'knows the error message_format' do
        expect(details.message_format).to eq('The domain is invalid: %s')
      end
    end

    describe '.new(name) with an invalid code' do
      let(:name) { 'invalid name' }

      it 'blows up immeditately' do
        expect { Details.new(name) }.to raise_error(KeyError)
      end
    end
  end
end
