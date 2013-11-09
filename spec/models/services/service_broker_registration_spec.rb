require 'spec_helper'
require 'models/services/service_broker_registration'

module VCAP::CloudController
  describe ServiceBrokerRegistration do
    describe '#save' do
      let(:broker) do
        ServiceBroker.new(
          name: 'Cool Broker',
          broker_url: 'http://broker.example.com',
          auth_username: 'cc',
          auth_password: 'auth1234',
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
        }.to change(ServiceBroker, :count).from(0).to(1)

        expect(broker).to eq(ServiceBroker.last)

        expect(broker.name).to eq('Cool Broker')
        expect(broker.broker_url).to eq('http://broker.example.com')
        expect(broker.auth_username).to eq('cc')
        expect(broker.auth_password).to eq('auth1234')
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
            }.to raise_error ServiceBroker::V2::ServiceBrokerBadResponse
          end

          it 'does not create a new service broker' do
            expect {
              registration.save(raise_on_failure: false) rescue nil
            }.to_not change(ServiceBroker, :count)
          end
        end
      end

      context 'when exception is raised during transaction' do
        context 'when broker already exists' do
          before do
            broker.save
            broker.stub(:load_catalog).and_raise(Errors::ServiceBrokerInvalid.new('each service must have at least one plan'))
          end

          it 'does not update broker' do
            expect(ServiceBroker.count).to eq(1)
            broker.name = 'Awesome new broker name'

            expect{
              expect { registration.save(raise_on_failure: false) }.to raise_error(Errors::ServiceBrokerInvalid)
            }.to change{ServiceBroker.count}.by(0)
            broker.reload

            expect(broker.name).to eq('Cool Broker')
          end
        end

        context 'when broker does not exist' do
          before do
            broker.stub(:load_catalog).and_raise(Errors::ServiceBrokerInvalid.new('each service must have at least one plan'))
          end

          it 'does not save new broker' do
            expect(ServiceBroker.count).to eq(0)
            expect{
              expect { registration.save(raise_on_failure: false) }.to raise_error(Errors::ServiceBrokerInvalid)
            }.to change{ServiceBroker.count}.by(0)
          end
        end

      end

    end
  end
end
