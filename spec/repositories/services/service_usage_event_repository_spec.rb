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

      describe '#purge_and_reseed_started_apps!' do
        before do
          3.times do
            ManagedServiceInstance.make
          end

          3.times do
            UserProvidedServiceInstance.make
          end
        end

        it 'will purge all existing events' do
          ServiceInstance.each { |instance| instance.destroy }

          expect {
            repository.purge_and_reseed_service_instances!
          }.to change { ServiceUsageEvent.count }.to(0)
        end

        context 'when there are existing service instances' do
          before do
            ManagedServiceInstance.first.destroy
            UserProvidedServiceInstance.first.destroy
          end

          it 'reseeds only existing instances with CREATED events' do
            repository.purge_and_reseed_service_instances!

            service_instance_count    = ServiceInstance.count
            service_usage_event_count = ServiceUsageEvent.count
            created_event_count       = ServiceUsageEvent.where(state: ServiceUsageEventRepository::CREATED_EVENT_STATE).count

            expect(service_instance_count).to eq(service_usage_event_count)
            expect(service_usage_event_count).to eq(created_event_count)
          end

          it 'reseeds events with the current time' do
            reseed_time = Sequel.datetime_class.now

            repository.purge_and_reseed_service_instances!

            ServiceUsageEvent.each do |event|
              expect(event.created_at.to_i).to be >= reseed_time.to_i
            end
          end

          it 'reseeds using the correct service instance type' do
            repository.purge_and_reseed_service_instances!

            managed_instance_count       = ManagedServiceInstance.count
            user_provided_instance_count = UserProvidedServiceInstance.count

            managed_event_count       = ServiceUsageEvent.where(service_instance_type: 'managed_service_instance').count
            user_provided_event_count = ServiceUsageEvent.where(service_instance_type: 'user_provided_service_instance').count

            expect(managed_instance_count).to eq(managed_event_count)
            expect(user_provided_instance_count).to eq(user_provided_event_count)
          end
        end
      end
    end
  end
end
