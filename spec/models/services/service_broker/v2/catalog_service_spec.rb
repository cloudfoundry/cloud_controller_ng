require 'spec_helper'
require 'securerandom'

require 'models/services/service_broker/v2/catalog_service'

module VCAP::CloudController::ServiceBroker::V2
  describe CatalogService do
    def build_valid_service_attrs(opts = {})
      {
        'id' => opts[:id] || 'broker-provided-service-id',
        'metadata' => opts[:metadata] || {},
        'name' => opts[:name] || 'service-name',
        'description' => opts[:description] || 'The description of this service',
        'bindable' => opts[:bindable] || true,
        'tags' => opts[:tags] || [],
        'plans' => opts[:plans] || [build_valid_plan_attrs],
        'requires' => opts[:requires] || []
      }
    end

    def build_valid_plan_attrs(opts = {})
      {
        'id' => opts[:id] || 'broker-provided-plan-id',
        'metadata' => opts[:metadata] || {},
        'name' => opts[:name] || 'service-plan-name',
        'description' => opts[:description] || 'The description of the service plan'
      }
    end

    describe 'validations' do
      it 'validates that @broker_provided_id is a string' do
        attrs = build_valid_service_attrs(id: 123)
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service id should be a string, but had value 123'
      end

      it 'validates that @broker_provided_id is present' do
        attrs = build_valid_service_attrs
        attrs['id'] = nil
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service id must be non-empty and a string'
      end

      it 'validates that @name is a string' do
        attrs = build_valid_service_attrs(name: 123)
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service name should be a string, but had value 123'
      end

      it 'validates that @name is present' do
        attrs = build_valid_service_attrs
        attrs['name'] = nil
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service name must be non-empty and a string'
      end

      it 'validates that @description is a string' do
        attrs = build_valid_service_attrs(description: 123)
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service description should be a string, but had value 123'
      end

      it 'validates that @description is present' do
        attrs = build_valid_service_attrs
        attrs['description'] = nil
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service description must be non-empty and a string'
      end

      it 'validates that @bindable is a boolean' do
        attrs = build_valid_service_attrs(bindable: "true")
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service "bindable" field should be a boolean, but had value "true"'
      end

      it 'validates that @bindable is present' do
        attrs = build_valid_service_attrs
        attrs['bindable'] = nil
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service "bindable" field must be present and a boolean'
      end

      it 'validates that @tags is an array of strings' do
        attrs = build_valid_service_attrs(tags: "a string")
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service tags should be an array of strings, but had value "a string"'

        attrs = build_valid_service_attrs(tags: [123])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service tags should be an array of strings, but had value [123]'
      end

      it 'validates that @requires is an array of strings' do
        attrs = build_valid_service_attrs(requires: "a string")
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service "requires" field should be an array of strings, but had value "a string"'

        attrs = build_valid_service_attrs(requires: [123])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service "requires" field should be an array of strings, but had value [123]'
      end

      it 'validates that @metadata is a hash' do
        attrs = build_valid_service_attrs(metadata: ['list', 'of', 'strings'])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service metadata should be a hash, but had value ["list", "of", "strings"]'
      end

      it 'validates that the plans list is an array of hashes' do
        attrs = build_valid_service_attrs(plans: "invalid")
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service plans list should be an array of hashes, but had value "invalid"'

        attrs = build_valid_service_attrs(plans: ["list", "of", "strings"])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'service plans list should be an array of hashes, but had value ["list", "of", "strings"]'
      end

      it 'validates that the plans list is not empty' do
        attrs = build_valid_service_attrs(plans: [])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'each service must have at least one plan'
      end

      it 'validates that the plan ids are all unique' do
        attrs = build_valid_service_attrs(plans: [build_valid_plan_attrs(id: 'id-1'), build_valid_plan_attrs(id: 'id-1')])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'each plan ID must be unique'
      end

      it 'validates that the plan names are all unique' do
        attrs = build_valid_service_attrs(plans: [build_valid_plan_attrs(name: 'same-name'), build_valid_plan_attrs(name: 'same-name')])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'each plan name must be unique within the same service'
      end

      describe '#valid?' do
        it 'is false if service has errors' do
          attrs = build_valid_service_attrs(metadata: ['list', 'of', 'strings'])
          expect(CatalogService.new(double('broker'), attrs).valid?).to be_false
        end

        it 'is false if any plan has errors' do
          plan = double('plan')
          allow(plan).to receive(:valid?).and_return(false)

          attrs = build_valid_service_attrs()
          service = CatalogService.new(double('broker'), attrs)
          allow(service).to receive(:plans).and_return([plan])

          expect(service.valid?).to be_false
        end
      end
    end

    describe '#cc_service' do
      let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
      let(:broker_provided_id) { SecureRandom.uuid }
      let(:catalog_service) do
        described_class.new( service_broker,
          'id' => broker_provided_id,
          'name' => 'service-name',
          'description' => 'service description',
          'bindable' => true,
          'plans' => [build_valid_plan_attrs]
        )
      end

      context 'when a Service exists with the same service broker and broker provided id' do
        let!(:cc_service) do
          VCAP::CloudController::Service.make(
            unique_id: broker_provided_id,
            service_broker: service_broker
          )
        end

        it 'is that Service' do
          expect(catalog_service.cc_service).to eq(cc_service)
        end
      end

      context 'when a Service exists with a different service broker, but the same broker provided id' do
        let!(:cc_service) do
          VCAP::CloudController::Service.make(unique_id: broker_provided_id)
        end

        it 'is nil' do
          expect(catalog_service.cc_service).to be_nil
        end
      end
    end
  end
end
