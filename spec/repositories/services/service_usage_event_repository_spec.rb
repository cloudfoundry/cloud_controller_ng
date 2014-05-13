require 'spec_helper'
require 'repositories/services/service_usage_event_repository'

module VCAP::CloudController
  module Repositories::Services
    describe ServiceUsageEventRepository do
      subject(:repository) do
        ServiceUsageEventRepository.new
      end

      describe '#find' do
        context 'when the event exists' do
          let(:event) { ServiceUsageEvent.make }

          it 'should return the event' do
            expect(repository.find(event.guid)).to eq(event)
          end
        end

        context 'when the event does not exist' do
          it 'should return nil' do
            expect(repository.find('does-not-exist')).to be_nil
          end
        end
      end

      describe '#create_from_service_instance' do
        let(:custom_state) { 'CUSTOM' }

        context 'with managed service instance' do
          let(:service_instance) { ManagedServiceInstance.make }

          it 'will create an event which matches the service instance and custom state' do
            event = repository.create_from_service_instance(service_instance, custom_state)

            expect(event.state).to eq(custom_state)
            expect(event).to match_service_instance(service_instance)
          end

          context 'fails to create the event if no custom state provided' do
            it 'will raise an error' do
              expect {
                repository.create_from_service_instance(service_instance, nil)
              }.to raise_error
            end
          end

          context 'fails to create the event' do

            context 'if service instance does not have a space' do
              before do
                service_instance.space = nil
              end

              it 'will raise an error' do
                expect {
                  repository.create_from_service_instance(service_instance, custom_state)
                }.to raise_error
              end
            end

          end
        end

        context 'with user provided service instance' do
          let(:service_instance) { UserProvidedServiceInstance.make }

          it 'will create an event if service instance does not have a service plan' do
            event = repository.create_from_service_instance(service_instance, custom_state)

            expect(event.state).to eq(custom_state)
            expect(event).to match_service_instance(service_instance)
          end
        end

      end
    end
  end
end
