require 'spec_helper'
require 'models/services/service_broker_registration'

module VCAP::CloudController::Models
  describe ServiceBrokerRegistration do
    before { reset_database }

    describe '#save' do
      let(:broker) do
        ServiceBroker.new(
          name: 'Cool Broker',
          broker_url: 'http://broker.example.com',
          token: 'auth1234'
        )
      end

      subject(:registration) { ServiceBrokerRegistration.new(broker) }

      before do
        stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(body: '{}')
      end

      it 'returns itself' do
        expect(registration.save(raise_on_failure: false)).to eq(registration)
      end

      it 'creates a service broker' do
        expect {
          registration.save(raise_on_failure: false)
        }.to change(ServiceBroker, :count).by(1)

        expect(broker).to eq(ServiceBroker.last)

        expect(broker.name).to eq('Cool Broker')
        expect(broker.broker_url).to eq('http://broker.example.com')
        expect(broker.token).to eq('auth1234')
        expect(broker).to be_exists
      end

      it 'fetches the catalog' do
        registration.save(raise_on_failure: false)

        expect(a_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog')).to have_been_requested
      end

      it 'resets errors before saving' do
        registration.broker.name = ''
        expect(registration.save(raise_on_failure: false)).to be_nil
        expect(registration.errors.on(:name)).to have_exactly(1).error
        expect(registration.save(raise_on_failure: false)).to be_nil
        expect(registration.errors.on(:name)).to have_exactly(1).error
      end

      context 'when invalid' do
        context 'because the broker has errors' do
          let(:broker) { ServiceBroker.new }
          let(:registration) { ServiceBrokerRegistration.new(broker) }

          it 'returns nil' do
            expect(registration.save(raise_on_failure: false)).to be_nil
          end

          it 'does not create a new service broker' do
            expect {
              registration.save(raise_on_failure: false)
            }.to_not change(ServiceBroker, :count)
          end

          it 'does not fetch the catalog' do
            registration.save(raise_on_failure: false)

            expect(a_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog')).to_not have_been_requested
          end

          it 'adds the broker errors to the registration errors' do
            registration.save(raise_on_failure: false)

            expect(registration.errors.on(:name)).to include(:presence)
          end
        end

        context 'because the catalog fetch failed' do
          before { stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(status: 500) }

          it 'raises an error, even though we\'d rather it not' do
            expect {
              registration.save(raise_on_failure: false)
            }.to raise_error
          end

          it 'does not create a new service broker' do
            expect {
              registration.save(raise_on_failure: false) rescue nil
            }.to_not change(ServiceBroker, :count)
          end
        end
      end
    end
  end
end
