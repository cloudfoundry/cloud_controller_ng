require 'spec_helper'
require 'decorators/field_service_offering_service_broker_decorator'
require 'field_decorator_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe FieldServiceOfferingServiceBrokerDecorator do
    describe '.decorate' do
      let(:offering1) { Service.make }
      let(:offering2) { Service.make }

      it 'decorated the given hash with broker name and guid' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ service_broker: ['name', 'guid'] })

        hash = decorator.decorate(undecorated_hash, [offering1, offering2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_brokers: [
              {
                guid: offering1.service_broker.guid,
                name: offering1.service_broker.name
              },
              {
                guid: offering2.service_broker.guid,
                name: offering2.service_broker.name
              }
            ]
          }
        })
      end

      context 'when offerings are from the same broker' do
        let(:offering3) { Service.make(service_broker: offering1.service_broker) }

        it 'does not duplicate the broker' do
          decorator = described_class.new({ service_broker: ['name'] })
          hash = decorator.decorate({}, [offering1, offering3])
          expect(hash[:included][:service_brokers]).to have(1).element
        end
      end
    end

    describe '.match?' do
      it_behaves_like 'field decorator match?', 'service_broker', ['name', 'guid']
    end
  end
end
