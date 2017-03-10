require 'spec_helper'
require 'repositories/service_usage_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe ServiceUsageEventRepository do
      let(:guid_pattern) { '[[:alnum:]-]+' }

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
              }.to raise_error(Sequel::NotNullConstraintViolation)
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
                }.to raise_error(NoMethodError)
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

          allow(ServiceUsageEvent.dataset).to receive(:truncate) do
            ServiceUsageEvent.dataset.destroy
          end

          ManagedServiceInstance.all.each do |service_instance|
            service_broker = service_instance.service.service_broker
            uri = URI(service_broker.broker_url)
            broker_url = uri.host + uri.path
            stub_request(:delete, %r{https://#{service_broker.auth_username}:#{service_broker.auth_password}@#{broker_url}/v2/service_instances/#{guid_pattern}}).
              to_return(status: 200, body: '{}')
          end
        end

        it 'will purge all existing events' do
          ServiceInstance.all.each(&:destroy)

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

            ServiceUsageEvent.all.each do |event|
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

      describe '#delete_events_older_than' do
        let!(:service_instance) { ManagedServiceInstance.make }
        let(:cutoff_age_in_days) { 1 }
        before do
          ServiceUsageEvent.dataset.delete

          old = Time.now.utc - 999.days

          3.times do
            event = repository.create_from_service_instance(service_instance, 'SOME-STATE')
            event.created_at = old
            event.save
          end
        end

        it 'will delete events created before the specified cutoff time' do
          new_event = repository.create_from_service_instance(service_instance, 'SOME-STATE')

          expect {
            repository.delete_events_older_than(cutoff_age_in_days)
          }.to change {
            ServiceUsageEvent.count
          }.to(1)

          expect(ServiceUsageEvent.last).to eq(new_event.reload)
        end
      end
    end
  end
end
