require 'spec_helper'
require 'actions/services/service_key_delete'

module VCAP::CloudController
  RSpec.describe ServiceKeyDelete do
    let(:guid_pattern) { '[[:alnum:]-]+' }
    subject(:service_key_delete) { ServiceKeyDelete.new }

    def broker_url(broker)
      base_broker_uri = URI.parse(broker.broker_url)
      base_broker_uri.user = broker.auth_username
      base_broker_uri.password = broker.auth_password
      base_broker_uri.to_s
    end

    def service_key_url_regex(opts={})
      service_key = opts[:service_key]
      service_key_guid = service_key.try(:guid) || guid_pattern
      service_instance = opts[:service_instance] || service_key.try(:service_instance)
      service_instance_guid = service_instance.try(:guid) || guid_pattern
      broker = opts[:service_broker] || service_instance.service_plan.service.service_broker
      %r{#{broker_url(broker)}/v2/service_instances/#{service_instance_guid}/service_bindings/#{service_key_guid}}
    end

    describe '#delete' do
      let!(:service_key_1) { ServiceKey.make }
      let!(:service_key_2) { ServiceKey.make }
      let(:service_instance) { service_key_1.service_instance }
      let!(:service_key_dataset) { ServiceKey.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:client) { VCAP::Services::ServiceBrokers::V2::Client }

      before do
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        allow(client).to receive(:unbind).and_return({})
      end

      it 'deletes the service keys' do
        service_key_delete.delete(service_key_dataset)

        expect { service_key_1.refresh }.to raise_error Sequel::Error, 'Record not found'
        expect { service_key_2.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      it 'deletes the service key from broker side' do
        service_key_delete.delete(service_key_dataset)
        expect(client).to have_received(:unbind).with(service_key_1)
        expect(client).to have_received(:unbind).with(service_key_2)
      end

      it 'fails if the instance has another operation in progress' do
        service_instance.service_instance_operation = ServiceInstanceOperation.make state: 'in progress'
        errors = service_key_delete.delete([service_key_1])
        expect(errors.first).to be_instance_of CloudController::Errors::ApiError
      end

      context 'when one key deletion fails' do
        let(:service_key_3) { ServiceKey.make }

        before do
          allow(client).to receive(:unbind).with(service_key_1).and_return({})
          allow(client).to receive(:unbind).with(service_key_2).and_raise('meow')
          allow(client).to receive(:unbind).with(service_key_3).and_return({})
        end

        it 'deletes all other keys' do
          service_key_delete.delete(service_key_dataset)

          expect { service_key_1.refresh }.to raise_error Sequel::Error, 'Record not found'
          expect { service_key_2.refresh }.not_to raise_error
          expect { service_key_3.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'returns all of the errors caught' do
          errors = service_key_delete.delete(service_key_dataset)
          expect(errors[0].message).to eq('meow')
        end
      end
    end
  end
end
