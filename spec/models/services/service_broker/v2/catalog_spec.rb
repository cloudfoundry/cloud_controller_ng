require 'spec_helper'

require 'models/services/service_broker/v2/catalog'

module VCAP::CloudController::ServiceBroker::V2
  describe Catalog do
    describe 'validations' do
      let(:broker) { double(VCAP::CloudController::ServiceBroker, errors: double.as_null_object) }

      def service_entry(opts = {plans: [plan_entry]} )
        {
          'id'          => Sham.guid,
          'name'        => Sham.name,
          'description' => Sham.description,
          'bindable'    => true,
          'tags'        => ['magical', 'webscale'],
          'plans'       => opts.fetch(:plans)
        }
      end

      def plan_entry(opts={id: Sham.guid})
        {
          'id'          => opts.fetch(:id),
          'name'        => Sham.name,
          'description' => Sham.description,
        }
      end

      context 'when a service has no plans' do
        let(:catalog) do
          {
            'services' => [
              service_entry,
              service_entry(plans: [])
            ]
          }
        end

        it 'throws an exception' do
          expect {
            Catalog.new(broker, catalog)
          }.to raise_error(VCAP::Errors::ServiceBrokerInvalid, /each service must have at least one plan/)
        end

        it 'adds an error to the broker' do
          Catalog.new(broker, catalog) rescue nil
          expect(broker.errors).to have_received(:add).with(:services, /each service must have at least one plan/)
        end
      end

      context 'when the catalog contains duplicate plan ids within a single service' do
        let(:catalog) do
          {
            'services' => [
              service_entry(plans: [
                                     plan_entry(id: 'abc123'),
                                     plan_entry(id: 'abc123'),
                                   ]
              )
            ]
          }
        end

        it 'throws an exception' do
          expect {
            Catalog.new(broker, catalog)
          }.to raise_error(VCAP::Errors::ServiceBrokerInvalid, /each plan ID must be unique/)
        end
      end
    end
  end
end
