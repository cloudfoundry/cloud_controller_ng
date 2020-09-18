require 'lightweight_spec_helper'
require 'cloud_controller/errors/v3/details'

module CloudController::Errors
  RSpec.describe V3::Details do
    describe '.new(name)' do
      let(:name) { 'ServiceBrokerNotRemovable' }

      subject(:details) do
        V3::Details.new(name)
      end

      it 'knows the error name' do
        expect(details.name).to eq('ServiceBrokerNotRemovable')
      end

      it 'knows the error http_code' do
        expect(details.response_code).to eq(422)
      end

      it 'knows code' do
        expect(details.code).to eq(270010)
      end

      it 'knows the error message_format' do
        expect(details.message_format).to eq('Can not remove brokers that have associated service instances: %s')
      end
    end

    describe '.new(name) with an invalid code' do
      let(:name) { 'invalid name' }

      it 'blows up immeditately' do
        expect { V3::Details.new(name) }.to raise_error(KeyError)
      end
    end
  end
end
