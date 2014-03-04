require 'spec_helper'
require 'models/services/validation_errors'
require 'models/services/service_brokers/validation_errors_formatter'
require 'models/services/service_broker/v2/catalog_service'
require 'models/services/service_broker/v2/catalog_plan'

module VCAP::CloudController::ServiceBrokers
  describe ValidationErrorsFormatter do
    describe "#format(validation_errors)" do
      let(:errors) { VCAP::CloudController::ValidationErrors.new }
      let(:service_broker) { double(:service_broker) }
      let(:service_1) { VCAP::CloudController::ServiceBroker::V2::CatalogService.new(service_broker, 'name' => 'service-1') }
      let(:service_2) { VCAP::CloudController::ServiceBroker::V2::CatalogService.new(service_broker, 'name' => 'service-2') }
      let(:plan_123)  { VCAP::CloudController::ServiceBroker::V2::CatalogPlan.new(service_2, 'name' => 'plan-123') }
      let(:service_3) { VCAP::CloudController::ServiceBroker::V2::CatalogService.new(service_broker, 'name' => 'service-3') }

      before do
        errors.add('Service ids must be unique')
        errors.add_nested(service_1).
          add('Service id must be a string, but has value 123')
        errors.add_nested(service_2).
          add('Plan ids must be unique').
          add_nested(plan_123).
          add('Plan name must be a string, but has value 123')
        errors.add_nested(service_3).
          add('At least one plan is required')
      end

      it 'builds a formatted string' do
        formatter = ValidationErrorsFormatter.new

        expect(formatter.format(errors)).to eq(<<HEREDOC)

Service ids must be unique
Service service-1
  Service id must be a string, but has value 123
Service service-2
  Plan ids must be unique
  Plan plan-123
    Plan name must be a string, but has value 123
Service service-3
  At least one plan is required
HEREDOC
      end
    end
  end
end
