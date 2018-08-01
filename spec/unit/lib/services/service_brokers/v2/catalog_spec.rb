require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe Catalog do
    let(:broker) { VCAP::CloudController::ServiceBroker.make }

    def service_entry(opts={})
      {
        'id'          => opts[:id] || Sham.guid,
        'name'        => opts[:name] || Sham.name,
        'description' => Sham.description,
        'bindable'    => true,
        'tags'        => ['magical', 'webscale'],
        'plans'       => opts[:plans] || [plan_entry]
      }
    end

    def plan_entry(opts={})
      {
        'id'          => opts[:id] || Sham.guid,
        'name'        => opts[:name] || Sham.name,
        'description' => Sham.description,
      }
    end

    let(:catalog) { Catalog.new(broker, catalog_hash) }

    describe 'validations' do
      context "when the catalog's services include errors" do
        let(:catalog_hash) do
          {
            'services' => [
              service_entry,
              service_entry(id: 123),
              service_entry(plans: [plan_entry(id: 'plan-id'), plan_entry(id: 'plan-id', name: 123)]),
              service_entry(plans: [])
            ]
          }
        end

        specify '#valid? returns false' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.nested_errors).not_to be_empty
        end
      end

      def build_service(attrs={})
        @index ||= 0
        @index += 1
        {
          'id' => @index.to_s,
          'name' => @index.to_s,
          'description' => 'the service description',
          'bindable' => true,
          'tags' => ['tag1'],
          'metadata' => { 'foo' => 'bar' },
          'plans' => [
            {
              'id' => @index.to_s,
              'name' => @index.to_s,
              'description' => 'the plan description',
              'metadata' => { 'foo' => 'bar' }
            }
          ]
        }.merge(attrs)
      end

      context 'when two services in the catalog have the same id' do
        let(:catalog_hash) do
          {
            'services' => [build_service('id' => '1'), build_service('id' => '1')]
          }
        end

        it 'gives an error' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to include('Service ids must be unique')
        end
      end

      context 'when two services in the catalog have the same dashboard_client id' do
        let(:catalog_hash) do
          {
            'services' => [
              build_service('dashboard_client' => {
                'id' => 'client-1',
                'secret' => 'secret',
                'redirect_uri' => 'http://example.com/client-1'
              }),
              build_service('dashboard_client' => {
                'id' => 'client-1',
                'secret' => 'secret2',
                'redirect_uri' => 'http://example.com/client-2'
              }),
            ]
          }
        end

        it 'gives an error' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to include('Service dashboard_client id must be unique')
        end
      end

      context "when a service's dashboard_client attribute is not a hash" do
        let(:catalog_hash) do
          { 'services' => [build_service('dashboard_client' => 1)] }
        end

        it 'gives an error' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
        end
      end

      context 'when there are multiple services without a dashboard_client' do
        let(:catalog_hash) do
          { 'services' => [build_service, build_service] }
        end

        it 'does not give a uniqueness error on dashboard_client id' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq true
        end
      end

      context 'when there are multiple services with a nil dashboard_client id' do
        let(:catalog_hash) do
          {
            'services' => [
              build_service('dashboard_client' => { 'id' => nil }),
              build_service('dashboard_client' => { 'id' => nil })
            ]
          }
        end

        it 'is invalid, but not due to uniqueness constraints' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to eq []
        end
      end

      context 'when there are multiple services with an empty id' do
        let(:catalog_hash) do
          { 'services' => [build_service('id' => nil), build_service('id' => nil)] }
        end

        it 'is invalid, but not due to uniqueness constraints' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to eq []
        end
      end

      context 'when there are both service validation problems and uniqueness problems' do
        let(:catalog_hash) do
          {
            'services' => [
              build_service('id' => 'service-1', 'dashboard_client' => { 'id' => 'client-1' }),
              build_service('id' => 'service-1', 'dashboard_client' => { 'id' => 'client-1' }),
            ]
          }
        end
        let(:catalog) { Catalog.new(broker, catalog_hash) }

        it 'is not valid' do
          expect(catalog).not_to be_valid
        end

        it 'has validation errors on the service' do
          catalog.valid?
          expect(catalog.errors.nested_errors).not_to be_empty
        end

        it 'has a validation error for duplicate service ids' do
          catalog.valid?
          expect(catalog.errors.messages).to include('Service ids must be unique')
        end

        it 'has a validation error for duplicate dashboard_client ids' do
          catalog.valid?
          expect(catalog.errors.messages).to include('Service dashboard_client id must be unique')
        end
      end
    end
  end
end
