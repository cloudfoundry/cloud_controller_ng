require 'spec_helper'
require 'securerandom'

require 'models/services/service_broker/v2/catalog_service'

module VCAP::CloudController::ServiceBroker::V2
  describe CatalogService do
    def build_valid_service_attrs(opts = {})
      {
        'id' => 'broker-provided-service-id',
        'metadata' => {},
        'name' => 'service-name',
        'description' => 'The description of this service',
        'bindable' => true,
        'tags' => [],
        'plans' => [build_valid_plan_attrs],
        'requires' => [],
        'dashboard_client' => {}
      }.merge(opts.stringify_keys)
    end

    def build_valid_plan_attrs(opts = {})
      {
        'id' => opts[:id] || 'broker-provided-plan-id',
        'metadata' => opts[:metadata] || {},
        'name' => opts[:name] || 'service-plan-name',
        'description' => opts[:description] || 'The description of the service plan'
      }
    end

    def build_valid_dashboard_client_attrs(opts={})
      {
        'id' => 'some-id',
        'secret' => 'some-secret',
        'redirect_uri' => 'http://redirect.com'
      }.merge(opts.stringify_keys)
    end

    describe 'validations' do
      it 'validates that @broker_provided_id is a string' do
        attrs = build_valid_service_attrs(id: 123)
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service id must be a string, but has value 123'
      end

      it 'validates that @broker_provided_id is present' do
        attrs = build_valid_service_attrs
        attrs['id'] = nil
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service id is required'
      end

      it 'validates that @name is a string' do
        attrs = build_valid_service_attrs(name: 123)
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service name must be a string, but has value 123'
      end

      it 'validates that @name is present' do
        attrs = build_valid_service_attrs
        attrs['name'] = nil
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service name is required'
      end

      it 'validates that @description is a string' do
        attrs = build_valid_service_attrs(description: 123)
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service description must be a string, but has value 123'
      end

      it 'validates that @description is present' do
        attrs = build_valid_service_attrs
        attrs['description'] = nil
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service description is required'
      end

      it 'validates that @bindable is a boolean' do
        attrs = build_valid_service_attrs(bindable: "true")
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service "bindable" field must be a boolean, but has value "true"'
      end

      it 'validates that @bindable is present' do
        attrs = build_valid_service_attrs
        attrs['bindable'] = nil
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service "bindable" field is required'
      end

      it 'validates that @tags is an array of strings' do
        attrs = build_valid_service_attrs(tags: "a string")
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service tags must be an array of strings, but has value "a string"'

        attrs = build_valid_service_attrs(tags: [123])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service tags must be an array of strings, but has value [123]'
      end

      it 'validates that @requires is an array of strings' do
        attrs = build_valid_service_attrs(requires: "a string")
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service "requires" field must be an array of strings, but has value "a string"'

        attrs = build_valid_service_attrs(requires: [123])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service "requires" field must be an array of strings, but has value [123]'
      end

      it 'validates that @metadata is a hash' do
        attrs = build_valid_service_attrs(metadata: ['list', 'of', 'strings'])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service metadata must be a hash, but has value ["list", "of", "strings"]'
      end

      it 'validates that the plans list is present' do
        attrs = build_valid_service_attrs(plans: nil)
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'At least one plan is required'
        expect(service.errors).not_to include 'Service plans list must be an array of hashes, but has value nil'
      end

      it 'validates that the plans list is an array' do
        attrs = build_valid_service_attrs(plans: "invalid")
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service plans list must be an array of hashes, but has value "invalid"'
        expect(service.errors).not_to include 'At least one plan is required'
      end

      it 'validates that the plans list is not empty' do
        attrs = build_valid_service_attrs(plans: [])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'At least one plan is required'
        expect(service.errors).not_to include 'Service plans list must be an array of hashes, but has value nil'
      end

      it 'validates that the plans list is an array of hashes' do
        attrs = build_valid_service_attrs(plans: ["list", "of", "strings"])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Service plans list must be an array of hashes, but has value ["list", "of", "strings"]'
        expect(service.errors).not_to include 'At least one plan is required'
      end

      it 'validates that the plan ids are all unique' do
        attrs = build_valid_service_attrs(plans: [build_valid_plan_attrs(id: 'id-1'), build_valid_plan_attrs(id: 'id-1')])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Plan id must be unique'
      end

      it 'validates that the plan names are all unique' do
        attrs = build_valid_service_attrs(plans: [build_valid_plan_attrs(name: 'same-name'), build_valid_plan_attrs(name: 'same-name')])
        service = CatalogService.new(double('broker'), attrs)
        service.valid?

        expect(service.errors).to include 'Plan names must be unique within a service'
      end

      context 'when dashboard_client attributes are provided' do
        it 'validates that the dashboard_client.id is present' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(id: nil)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors).to include 'Service dashboard client id is required'
        end

        it 'validates that the dashboard_client.id is a string' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(id: 123)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors).to include 'Service dashboard client id must be a string, but has value 123'
        end

        it 'validates that the dashboard_client.secret is present' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(secret: nil)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors).to include 'Service dashboard client secret is required'
        end

        it 'validates that the dashboard_client.secret is a string' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(secret: 123)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors).to include 'Service dashboard client secret must be a string, but has value 123'
        end

        it 'validates that the dashboard_client.redirect_uri is present' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(redirect_uri: nil)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors).to include 'Service dashboard client redirect_uri is required'
        end

        it 'validates that the dashboard_client.redirect_uri is a string' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(redirect_uri: 123)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors).to include 'Service dashboard client redirect_uri must be a string, but has value 123'
        end
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
