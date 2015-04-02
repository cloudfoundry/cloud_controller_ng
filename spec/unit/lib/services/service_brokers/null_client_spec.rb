require 'spec_helper'

module VCAP::Services::ServiceBrokers
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

      it 'returns a successful operation' do
        expect(client.deprovision(instance)).to eq(
          {
            last_operation: {
              state: 'succeeded'
            }
          }
        )
      end
    end
  end
end
