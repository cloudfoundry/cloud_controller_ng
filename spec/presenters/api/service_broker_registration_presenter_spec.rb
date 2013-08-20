require 'spec_helper'
require 'presenters/api/service_broker_registration_presenter'

module VCAP::CloudController
  describe ServiceBrokerRegistrationPresenter do
    let(:registration) do
      Models::ServiceBrokerRegistration.new(
        name: 'My Custom Service',
        broker_url: 'http://broker.example.com',
      )
    end

    subject(:presenter) { ServiceBrokerRegistrationPresenter.new(registration) }

    describe '#to_hash' do
      describe '[:metadata]' do
        subject(:metadata) { presenter.to_hash.fetch(:metadata) }

        it 'includes the guid' do
          registration.broker.guid = '1234abcdefg'
          expect(metadata.fetch(:guid)).to eq('1234abcdefg')
        end

        it 'includes the CC resource url' do
          registration.broker.guid = '1234abcdefg'
          expect(metadata.fetch(:url)).to eq('/v2/service_brokers/1234abcdefg')
        end
      end

      describe '[:entity]' do
        subject(:entity) { presenter.to_hash.fetch(:entity) }

        it 'does not include the token' do
          expect(entity).to_not have_key(:token)
        end

        it 'includes the name' do
          expect(entity.fetch(:name)).to eq('My Custom Service')
        end

        it 'includes the endpoint url' do
          expect(entity.fetch(:broker_url)).to eq('http://broker.example.com')
        end
      end
    end
  end
end
