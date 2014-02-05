require 'spec_helper'
require 'models/services/service_brokers/null_client'

module VCAP::CloudController::ServiceBrokers
  describe NullClient do
    let(:client) { NullClient.new }

    describe '#unbind' do
      let(:binding) { double(:binding) }

      it 'returns an empty hash' do
        expect(client.unbind(binding)).to eq({})
      end
    end

    describe '#deprovision' do
      let(:instance) { double(:instance) }

      it 'returns an empty hash' do
        expect(client.deprovision(instance)).to eq({})
      end
    end
  end
end
